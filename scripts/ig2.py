import asyncio
import http.client
import json
import random

from config import headers_comment, headers_followers, headers_following

# CONSTANTS
delay = 0.4  # s
WORKERS = 5
comment_counter = 0
AT_SIGN = "%40"

async def async_loop(func):
    while True:
        await asyncio.to_thread(func)  # runs in background thread


# Get a list of usernames that follow me
def get_followers(headers: dict[str, str], count: int) -> list[str]:
    followers: list[str] = []

    conn = http.client.HTTPSConnection("www.instagram.com")

    conn.request(
        "GET",
        f"/api/v1/friendships/75712779519/followers/?count={count}&search_surface=follow_list_page",
        headers=headers,
    )
    response = conn.getresponse()
    json_data = json.loads(response.read())
    users_length = len(json_data["users"])
    followers = [json_data["users"][i]["username"] for i in range(users_length)]

    return followers


# Get a list of usernames that I follow
def get_following(headers: dict[str, str], count: int) -> list[str]:
    following: list[str] = []

    conn = http.client.HTTPSConnection("www.instagram.com")

    conn.request(
        "GET", f"/api/v1/friendships/75712779519/following/?count={count}", headers=headers
    )
    response = conn.getresponse()
    json_data = json.loads(response.read())
    users_length = len(json_data["users"])
    following = [json_data["users"][i]["username"] for i in range(users_length)]

    return following


def do_comment_request(comment: str) -> int:
    # post_id = 3784430213149781314
    post_id = 3785127233443372196

    connmain = http.client.HTTPSConnection("www.instagram.com")
    connmain.request(
        "POST",
        f"/api/v1/web/comments/{post_id}/add/",
        f"comment_text={comment}+&jazoest=21991",
        headers_comment,
    )
    response = connmain.getresponse()

    # data = response.read()

    connmain.close()
    return response.status


async def main():
    try:

        followers = await asyncio.to_thread(get_followers, headers_followers, 50)
        following = await asyncio.to_thread(get_following, headers_following, 50)
        print(followers)
        print("Length of followers: ", len(followers))
        print(following)
        print("Length of following: ", len(following))

        global comment_counter
        while True:
            follower_username = random.choice(followers)
            following_username = random.choice(following)
            username_to_tag = random.choice([follower_username, following_username])
            print(f"Tagging {username_to_tag}...")
            comment: str = AT_SIGN + username_to_tag
            status = await asyncio.to_thread(do_comment_request, comment)
            comment_counter += 1
            print(f"Comment {comment_counter} -> status: ", status)
            await asyncio.sleep(delay)



    except KeyboardInterrupt:
        print("Exited by keyboard interrupt succesfully")

    except asyncio.exceptions.CancelledError:
        print("Exited by cancelling request succesfully")

    finally:
        print("Program finished succesfully")


if __name__ == "__main__":
    asyncio.run(main())
