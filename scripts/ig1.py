import requests

cookies = {
    'sessionid': '75712779519%3APOkVt9lXSwRn0K%3A22%3AAYhgPrvUAg0dsdVXhKexnY6dSdZQVgherIEQ0P1BJw',
    'ds_user_id': '75712779519',
    'csrftoken': 'Q4zpS8iXrBZarcQTYZq6ed',
    'mid': 'aTmyxQALAAEYb1XYQpzsTai-2Upm',
    'ig_did': 'A5654AFE-A8D4-4F7F-8C97-732885066CC9',
    'datr': 'z7I5aYue1H1CL9TxqbzZZuNt',
    'wd': '1769x1308',
    'rur': '"RVA\\05475712779519\\0541796933255:01feb0dfb2213b047e0cbe0b5050d5bf7a5129e4a47792da7261f00d3942f46b53667a23"',
}

headers = {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.6',
    'content-type': 'application/x-www-form-urlencoded',
    'dnt': '1',
    'origin': 'https://www.instagram.com',
    'priority': 'u=1, i',
    'referer': 'https://www.instagram.com/p/DSE_zpkDG1C/',
    'sec-ch-ua': '"Brave";v="143", "Chromium";v="143", "Not A(Brand";v="24"',
    'sec-ch-ua-full-version-list': '"Brave";v="143.0.0.0", "Chromium";v="143.0.0.0", "Not A(Brand";v="24.0.0.0"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-model': '""',
    'sec-ch-ua-platform': '"Windows"',
    'sec-ch-ua-platform-version': '"15.0.0"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-origin',
    'sec-gpc': '1',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
    'x-asbd-id': '359341',
    'x-csrftoken': 'Q4zpS8iXrBZarcQTYZq6ed',
    'x-ig-app-id': '936619743392459',
    'x-ig-www-claim': 'hmac.AR3lZimQS0uXB8PVE6cFql0LrfRe_YFW7tm4ZTxbj6qiwAht',
    'x-instagram-ajax': '1030884839',
    'x-requested-with': 'XMLHttpRequest',
    'x-web-session-id': 'jvkoln:hw42gh:cec85w',
    # 'cookie': 'sessionid=75712779519%3APOkVt9lXSwRn0K%3A22%3AAYhgPrvUAg0dsdVXhKexnY6dSdZQVgherIEQ0P1BJw; ds_user_id=75712779519; csrftoken=Q4zpS8iXrBZarcQTYZq6ed; mid=aTmyxQALAAEYb1XYQpzsTai-2Upm; ig_did=A5654AFE-A8D4-4F7F-8C97-732885066CC9; datr=z7I5aYue1H1CL9TxqbzZZuNt; wd=1769x1308; rur="RVA\\05475712779519\\0541796933255:01feb0dfb2213b047e0cbe0b5050d5bf7a5129e4a47792da7261f00d3942f46b53667a23"',
}

data = {
    'comment_text': '@cmariussz ',
    'jazoest': '21991',
}

response = requests.post(
    'https://www.instagram.com/api/v1/web/comments/3784430213149781314/add/',
    cookies=cookies,
    headers=headers,
    data=data,
)