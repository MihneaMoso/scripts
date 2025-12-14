import asyncio
import http.client
import json
import random
from pprint import pprint

from config import headers_comment, headers_followers, headers_following, headers_posts, headers_user

# CONSTANTS
DELAY = 0.4  # s
BIG_DELAY = 5
WORKERS = 5
AT_SIGN = "%40"
HOST: str = "www.instagram.com"
comment_counter = 0
global_headers: dict[str, str] = {}

def setup_headers():
    global global_headers
    for headers in [headers_comment, headers_followers, headers_following, headers_posts, headers_user]:
        for k,v in headers.items():
            if k not in global_headers:
                global_headers[k] = v

async def async_loop(func):
    while True:
        await asyncio.to_thread(func)  # runs in background thread


class SimpleSession:
    def __init__(self, host: str):
        self.host: str = host
        self.cookies: dict = {}
        self.default_headers: dict[str, str] = global_headers
        # self.good_headers: dict[str, str] = global_headers

    def _cookie_header(self):
        return "; ".join(f"{k}={v}" for k, v in self.cookies.items())

    def request(self, method: str, path: str, payload: str = ""):
        conn = http.client.HTTPSConnection(self.host, timeout=5)

        headers = dict(self.default_headers)
        # pprint(f"Using headers: {headers}")
        if self.cookies:
            headers["cookie"] = self._cookie_header()

        conn.request(method, path, payload, headers=headers)
        resp = conn.getresponse()

        body = resp.read()
        resp_headers = dict(resp.getheaders())

        # Extract cookies
        if "Set-Cookie" in resp_headers:
            raw = resp_headers["Set-Cookie"]
            cookie = raw.split(";", 1)[0]
            k, v = cookie.split("=", 1)
            self.cookies[k] = v

        conn.close()
        return resp.status, resp_headers, body



# Get a list of usernames that follow me
def get_followers(count: int, user_id: int) -> list[str]:
    followers: list[str] = []

    session = SimpleSession(HOST)
    status, resp_headers, body = session.request("GET", f"/api/v1/friendships/{user_id}/followers/?count={count}&search_surface=follow_list_page")
    # print(f"Headers for followers: {response.getheaders()}")
    
    json_data = json.loads(body)
    
    users_length = len(json_data["users"])
    followers = [json_data["users"][i]["username"] for i in range(users_length)]

    return followers


# Get a list of usernames that I follow
def get_following(count: int, user_id: int) -> list[str]:
    following: list[str] = []

    session = SimpleSession(HOST)
    status, resp_headers, body = session.request("GET", f"/api/v1/friendships/{user_id}/following/?count={count}")
    # print(f"Headers for following: {response.getheaders()}")
    
    json_data = json.loads(body)
    
    users_length = len(json_data["users"])
    following = [json_data["users"][i]["username"] for i in range(users_length)]

    return following

def get_user_id(username: str) -> int:
    
    payload = 'av=17841475705584097&__d=www&__user=0&__a=1&__req=1&__hs=20436.HCSV2%3Ainstagram_web_pkg.2.1...0&dpr=1&__ccg=EXCELLENT&__rev=1031064587&__s=i5fzvf%3Ahw42gh%3Aetslb3&__hsi=7583654752951851235&__dyn=7xe5WwlEnwn8K2Wmh0no6u5U4e1ZyUW3qi2K360O81nEhw2nVE4W0qa0FE2awgo9o1vohwGwQwoEcE2ygao1aU2swbOU2zxe2GewGw9a361qw8W5U4q08OwLyES1Twoob82ZwrUdUbGwmk0KU6O1FwlA1HQp1yU426V8aUuwm8jwhU3cyVrx60hK16wOw8-2i&__csr=gx2kBih4jsQdEBRSQx4aSICBNcZ9lYyKKLnGVsGFa8LCjJ29bGjK64H-rmECXF4VQGSy4OqAmqvJp5K2i7u2bDQQiUO68ybDCxacK3q8G2edwBDxO27UK68O48G4qggHQWx2BwLxm26FbzpFo98KqUOcWB8q1lxG2y2m08qw05tLw4LGaK09_Ct052AXweybyo0Sq04k80kB80a8wtUCbw5gwmQ0duwvay40jy1cwhYg0aqyWO014C3G1Mw0u7E11C0bXw0SLw&__hsdp=kMx8wEixtdnFpKAc284J6jFmXFeaFeqbypkihBtCLye8dzlzCjK78WVoIFK10hk4CykykWPjn50q85W7U6e1CzUvyEBx65Wxde1xw7Kxq0vW320ka02eu0lPw5uw1oe0pm11w&__hblp=050w8i9wtovwdC1rxq1RGm9zohBAzEWaAyEgwqovwAz81a8eE9ESUmwZwVK0ke3m8xe78-19xO18zE7e04po0R-0OE5q9w8yi267E2Qwei1aw3sE1bo3yx61Ix62W4o33wgo3Rw&__sjsp=kMx8wEixtdnFpKAc284J6jCAKF8Guqbypkih6tyK8Ux5zk46jK78796x9EB8BeIDdt0s87W0gZw&__comet_req=7&fb_dtsg=NAftfb8_jyb1aqsBfLCR-T5lPggUQ-3AU-P4nS5BN41JhqJy6Qk80gw%3A17853599968089360%3A1765388998&jazoest=26086&lsd=XjIgre_QAF--dATeFW577U&__spin_r=1031064587&__spin_b=trunk&__spin_t=1765707217&fb_api_caller_class=RelayModern&fb_api_req_friendly_name=PolarisProfilePageContentQuery&server_timestamps=true&variables=%7B%22enable_integrity_filters%22%3Atrue%2C%22id%22%3A%2275712779519%22%2C%22render_surface%22%3A%22PROFILE%22%2C%22__relay_internal__pv__PolarisProjectCannesLoggedInEnabledrelayprovider%22%3Atrue%2C%22__relay_internal__pv__PolarisCannesGuardianExperienceEnabledrelayprovider%22%3Atrue%2C%22__relay_internal__pv__PolarisCASB976ProfileEnabledrelayprovider%22%3Afalse%2C%22__relay_internal__pv__PolarisRepostsConsumptionEnabledrelayprovider%22%3Afalse%7D&doc_id=33257018913889225'

    session = SimpleSession(HOST)
    status, resp_headers, body = session.request("POST", '/graphql/query', payload=payload)
    # print(body)

    json_data = json.loads(body)
    pk: int = json_data["data"]["user"]["pk"]
    return pk

def get_nth_latest_postid_title(n: int = 0) -> tuple[int, str]:
    
    payload = 'av=17841475705584097&__d=www&__user=0&__a=1&__req=5&__hs=20435.HCSV2%3Ainstagram_web_pkg.2.1...0&dpr=1&__ccg=EXCELLENT&__rev=1031050016&__s=ecx9im%3Ahw42gh%3A6yrpka&__hsi=7583284367174623780&__dyn=7xe6E5q5U5ObwKBAg5S1Dxu13wvoKewSAwHwNwcy0lW4o0B-q1ew6ywaq0yE460qe4o5-1ywOwa90Fw4Hw9O0M82zxe2GewGw9a361qw8W1uw2oEGdwtU662O0Lo6-3u2WE15E6O1FwlE6PhA6bwg8rAwHxW1oxe17wcObBK4o16U4q3a0zU98&__csr=ih4BcPhBOuYcJbmnqAXUCGnFtCyBryeulGi48O-68aUqyVEcUbU4G1Zg8HG2a4o-UgxG48cK5UWEK1WDw8O48rxy2h3V8G9G6oa85h006M4G04qm16x6041602dG&__hsdp=p0B5n4c8lQ9gCcPFbwj9uUKA4V-5GBuGiK-dUpVEOCEbE2exvQUgpeaju1EwlE1dpQ6804arw&__sjsp=p0B5n4c8lQ9gCcPFbwj9ufF1evxClAFaXz-6uqcFG2W0zEnZe46jyATwq8&__comet_req=7&fb_dtsg=NAfvL_Ia3e1YdP4mvOr-2PezXdcflrTCk6an3vv8DV2O_ozxW9NjPew%3A17853599968089360%3A1765388998&jazoest=26448&lsd=EURIpDDMu0fz4ePVVo-u0e&__spin_r=1031050016&__spin_b=trunk&__spin_t=1765620980&fb_api_caller_class=RelayModern&fb_api_req_friendly_name=PolarisProfilePostsQuery&server_timestamps=true&variables=%7B%22data%22%3A%7B%22count%22%3A12%2C%22include_reel_media_seen_timestamp%22%3Atrue%2C%22include_relationship_info%22%3Atrue%2C%22latest_besties_reel_media%22%3Atrue%2C%22latest_reel_media%22%3Atrue%7D%2C%22username%22%3A%22sportarenastreetball%22%2C%22__relay_internal__pv__PolarisIsLoggedInrelayprovider%22%3Atrue%7D&doc_id=25352076627737294'
    session = SimpleSession(HOST)
    status, resp_headers, body = session.request("POST", '/graphql/query', payload=payload)
    
    json_data = json.loads(body)
    edges = json_data["data"]["xdt_api__v1__feed__user_timeline_graphql_connection"]["edges"]
    id: int = edges[n]["node"]["pk"]
    title: str = edges[n]["node"]["caption"]["text"]
    return (id, title)

def do_comment_request(comment: str, post_id: int) -> int:
    # post_id = 3784430213149781314
    # post_id = 3785127233443372196
    # post_id = 3785867440086106421

    # connmain = http.client.HTTPSConnection(HOST)
    # connmain.request(
    #     "POST",
    #     f"/api/v1/web/comments/{post_id}/add/",
    #     f"comment_text={comment}+&jazoest=21991",
    #     headers_comment,
    # )
    # response = connmain.getresponse()
    
    path = f"/api/v1/web/comments/{post_id}/add/"
    payload = f"comment_text={comment}+&jazoest=21991"
    session = SimpleSession(HOST)
    status, resp_headers, body = session.request("POST", path, payload=payload)
    
    # print(f"Headers for comment: {response.getheaders()}")
    # print(f"Body: {body[:500]}")


    return status


async def main():
    try:
        setup_headers()
        username: str = "bogdandumitru_"
        user_id = get_user_id(username)
        print(f"User id: {user_id}")

        followers = await asyncio.to_thread(get_followers, 100, user_id)
        following = await asyncio.to_thread(get_following, 100, user_id)
        print(followers)
        print("Length of followers: ", len(followers))
        print(following)
        print("Length of following: ", len(following))
        pool = set(followers).union(set(following))
        
        latest_post_id, post_title = get_nth_latest_postid_title(n = 0)
        print(f"Latest post id: {latest_post_id} with the title {post_title}")

        global comment_counter
        while True:
            # follower_username = random.choice(followers)
            # following_username = random.choice(following)
            username_to_tag = random.choice(list(pool))
            print(f"Tagging {username_to_tag}...")
            comment: str = AT_SIGN + username_to_tag
            status = await asyncio.to_thread(do_comment_request, comment, latest_post_id)
            if (status == 400):
                print("Status 400 encountered, cooldown for 5s")
                await asyncio.sleep(BIG_DELAY)
            comment_counter += 1
            print(f"Comment {comment_counter} -> status: ", status)
            await asyncio.sleep(DELAY)



    except KeyboardInterrupt:
        print("Exited by keyboard interrupt succesfully")

    except asyncio.exceptions.CancelledError:
        print("Exited by cancelling request succesfully")

    finally:
        print("Program finished succesfully")


if __name__ == "__main__":
    asyncio.run(main())
