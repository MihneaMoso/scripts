import random
import time
import asyncio
from typing import Optional, Dict, Any, Iterable, Tuple
from curl_cffi import requests

# Small helper to parse cookie string "a=1; b=2"
def parse_cookie_string(cookie_str: str) -> Dict[str, str]:
    cookies = {}
    for part in cookie_str.split(";"):
        part = part.strip()
        if not part:
            continue
        if "=" in part:
            k, v = part.split("=", 1)
            cookies[k.strip()] = v.strip()
    return cookies

class CurlSession:
    """
    CurlSession — wrapper around curl_cffi.requests.Session or AsyncSession.

    - async_mode: if True, creates an AsyncSession and .arequest is async.
    - impersonate: initial impersonation target (e.g. "chrome124" or "chrome").
    - rotate_every_min/rotate_every_max: rotate fingerprint after random N in [min,max].
    - preserve_cookies_on_rotate: keep cookies when rotating identity.
    - max_retries/backoff_factor: retry/backoff settings on request failures.
    """

    DEFAULT_IMPERSONATE_POOL = [
        "chrome120", "chrome123", "chrome124", "chrome131",
        "chrome110", "chrome116", "safari17_2_ios", "safari18_0_ios"
    ]

    def __init__(
        self,
        async_mode: bool = False,
        impersonate: str | None = "chrome124",
        impersonate_pool: Optional[Iterable[str]] = None,
        rotate_every_min: int = 5,
        rotate_every_max: int = 10,
        preserve_cookies_on_rotate: bool = True,
        max_retries: int = 3,
        backoff_factor: float = 0.5,
        timeout: float = 10.0,
        **session_kwargs
    ):
        self.async_mode = async_mode
        self.impersonate_pool = list(impersonate_pool or self.DEFAULT_IMPERSONATE_POOL)
        self.impersonate = impersonate or random.choice(self.impersonate_pool)
        self.rotate_every_min = rotate_every_min
        self.rotate_every_max = rotate_every_max
        self._next_rotate = random.randint(self.rotate_every_min, self.rotate_every_max)
        self._req_counter = 0
        self.preserve_cookies_on_rotate = preserve_cookies_on_rotate

        self.max_retries = max_retries
        self.backoff_factor = backoff_factor
        self.timeout = timeout

        # session_kwargs pass-through (proxies, verify, etc.)
        self._session_kwargs = dict(session_kwargs)

        # create the underlying session (sync or async)
        self._create_session()

    def _create_session(self):
        kwargs = dict(self._session_kwargs)
        kwargs.setdefault("timeout", self.timeout)
        # set impersonate on creation
        if self.impersonate:
            kwargs["impersonate"] = self.impersonate

        # create sync or async session
        if self.async_mode:
            # AsyncSession API mirrors requests.Session in curl_cffi
            self._session = requests.AsyncSession(**kwargs)
        else:
            self._session = requests.Session(**kwargs)

    def _close_session(self):
        try:
            self._session.close()
        except Exception:
            # AsyncSession.close is coroutine; handled in async close
            pass

    def _rotate_fingerprint(self):
        # choose a new impersonate target different from current
        choices = [p for p in self.impersonate_pool if p != self.impersonate]
        if not choices:
            return  # nothing to rotate to
        new_imp = random.choice(choices)
        # preserve cookies if requested
        cookies_backup = None
        if self.preserve_cookies_on_rotate:
            try:
                cookies_backup = {c.name: c.value for c in self._session.cookies}
            except Exception:
                cookies_backup = None

        # close and recreate
        self._close_session()
        self.impersonate = new_imp
        self._create_session()

        # restore cookies if we backed them up
        if cookies_backup:
            for k, v in cookies_backup.items():
                self._session.cookies.set(k, v)

        # reset counters
        self._req_counter = 0
        self._next_rotate = random.randint(self.rotate_every_min, self.rotate_every_max)

    def set_initial_cookies(self, cookie_string: str):
        """
        Accepts semicolon-separated "k=v; k2=v2" string and sets cookies into the session.
        """
        cookies = parse_cookie_string(cookie_string)
        for k, v in cookies.items():
            self._session.cookies.set(k, v)

    def _cookies_dict(self) -> Dict[str, str]:
        try:
            return {c.name: c.value for c in self._session.cookies}
        except Exception:
            # fallback: try mapping-like access (some cookie jars behave differently)
            try:
                return dict(self._session.cookies)
            except Exception:
                return {}

    # ----------------- SYNC request -----------------
    def request(self, method: str, url: str, *,
                headers: Optional[Dict[str, str]] = None,
                params: Optional[Dict[str, Any]] = None,
                data: Any = None,
                json: Any = None,
                allow_redirects: bool = True,
                timeout: Optional[float] = None,
                **kwargs) -> Tuple[int, Dict[str, str], str, Dict[str, str]]:
        """
        Synchronous request path. Returns (status_code, headers, text_body, cookies_dict).
        Retries with exponential backoff on exceptions or non-2xx if configured.
        """
        if self.async_mode:
            raise RuntimeError("Session created in async_mode; use arequest instead.")

        attempt = 0
        timeout = timeout if timeout is not None else self.timeout

        while True:
            attempt += 1
            try:
                resp = self._session.request(
                    method, url,
                    headers=headers,
                    params=params,
                    data=data,
                    json=json,
                    allow_redirects=allow_redirects,
                    timeout=timeout,
                    **kwargs
                )
                text = resp.text
                status = resp.status_code
                resp_headers = dict(resp.headers)

                # increment counter and maybe rotate
                self._req_counter += 1
                if self._req_counter >= self._next_rotate:
                    self._rotate_fingerprint()

                # on success return
                return status, resp_headers, text, self._cookies_dict()

            except Exception as exc:
                if attempt > self.max_retries:
                    raise
                # exponential backoff with jitter
                backoff = self.backoff_factor * (2 ** (attempt - 1))
                backoff = backoff * (1 + random.random() * 0.5)
                time.sleep(backoff)

    # ----------------- ASYNC request -----------------
    async def arequest(self, method: str, url: str, *,
                       headers: Optional[Dict[str, str]] = None,
                       params: Optional[Dict[str, Any]] = None,
                       data: Any = None,
                       json: Any = None,
                       allow_redirects: bool = True,
                       timeout: Optional[float] = None,
                       **kwargs) -> Tuple[int, Dict[str, str], str, Dict[str, str]]:
        """
        Async request path for AsyncSession. Returns (status_code, headers, text_body, cookies_dict).
        """
        if not self.async_mode:
            raise RuntimeError("Session created in sync mode; use request instead.")

        attempt = 0
        timeout = timeout if timeout is not None else self.timeout

        while True:
            attempt += 1
            try:
                resp = await self._session.request(
                    method, url,
                    headers=headers,
                    params=params,
                    data=data,
                    json=json,
                    allow_redirects=allow_redirects,
                    timeout=timeout,
                    **kwargs
                )
                text = await resp.text()
                status = resp.status_code
                resp_headers = dict(resp.headers)

                # increment counter and maybe rotate
                self._req_counter += 1
                if self._req_counter >= self._next_rotate:
                    # rotation requires recreating session which is sync;
                    # do it in a small thread to avoid blocking the loop
                    # but preserve cookies if desired.
                    # For simplicity here we perform rotation synchronously.
                    self._rotate_fingerprint()

                return status, resp_headers, text, self._cookies_dict()
            except Exception as exc:
                if attempt > self.max_retries:
                    raise
                backoff = self.backoff_factor * (2 ** (attempt - 1))
                backoff = backoff * (1 + random.random() * 0.5)
                await asyncio.sleep(backoff)

    # convenience wrappers
    def get(self, url: str, **kwargs):
        if self.async_mode:
            return self.arequest("GET", url, **kwargs)
        return self.request("GET", url, **kwargs)

    def post(self, url: str, **kwargs):
        if self.async_mode:
            return self.arequest("POST", url, **kwargs)
        return self.request("POST", url, **kwargs)

    def close(self):
        """Close the session (sync)."""
        if self.async_mode:
            raise RuntimeError("async_mode session should call aclose()")
        try:
            self._session.close()
        except Exception:
            pass

    async def aclose(self):
        """Close the async session (awaitable)."""
        if not self.async_mode:
            raise RuntimeError("sync-mode session should call close()")
        # AsyncSession.close() is a coroutine
        try:
            await self._session.close()
        except Exception:
            pass


def main():
    s = CurlSession(async_mode=False, impersonate="chrome124")
    s.set_initial_cookies("csrftoken=abc123; sessionid=deadbeef")
    status, headers, body, cookies = s.post(
        "https://example.com/",
        data={"username":"u","password":"p"}
    )
    print(status, cookies)
    s.close()


if __name__ == "__main__":
    main()
