import asyncio
import http.client
import json
import random

from config import headers_comment, headers_followers, headers_following, headers_posts

# CONSTANTS
delay = 0.4  # s
WORKERS = 5
comment_counter = 0
AT_SIGN = "%40"

async def async_loop(func):
    while True:
        await asyncio.to_thread(func)  # runs in background thread


# Get a list of usernames that follow me
def get_followers(count: int) -> list[str]:
    followers: list[str] = []

    conn = http.client.HTTPSConnection("www.instagram.com")

    conn.request(
        "GET",
        f"/api/v1/friendships/75712779519/followers/?count={count}&search_surface=follow_list_page",
        headers=headers_followers,
    )
    response = conn.getresponse()
    json_data = json.loads(response.read())
    users_length = len(json_data["users"])
    followers = [json_data["users"][i]["username"] for i in range(users_length)]

    return followers


# Get a list of usernames that I follow
def get_following(count: int) -> list[str]:
    following: list[str] = []

    conn = http.client.HTTPSConnection("www.instagram.com")

    conn.request(
        "GET", f"/api/v1/friendships/75712779519/following/?count={count}", headers=headers_following
    )
    response = conn.getresponse()
    json_data = json.loads(response.read())
    users_length = len(json_data["users"])
    following = [json_data["users"][i]["username"] for i in range(users_length)]

    return following


def get_nth_latest_postid(n: int = 0) -> tuple[int, str]:
    conn = http.client.HTTPSConnection('www.instagram.com')
    
    conn.request(
        'POST',
        '/graphql/query',
        'av=17841475705584097&__d=www&__user=0&__a=1&__req=5&__hs=20435.HCSV2%3Ainstagram_web_pkg.2.1...0&dpr=1&__ccg=EXCELLENT&__rev=1031050016&__s=ecx9im%3Ahw42gh%3A6yrpka&__hsi=7583284367174623780&__dyn=7xe6E5q5U5ObwKBAg5S1Dxu13wvoKewSAwHwNwcy0lW4o0B-q1ew6ywaq0yE460qe4o5-1ywOwa90Fw4Hw9O0M82zxe2GewGw9a361qw8W1uw2oEGdwtU662O0Lo6-3u2WE15E6O1FwlE6PhA6bwg8rAwHxW1oxe17wcObBK4o16U4q3a0zU98&__csr=ih4BcPhBOuYcJbmnqAXUCGnFtCyBryeulGi48O-68aUqyVEcUbU4G1Zg8HG2a4o-UgxG48cK5UWEK1WDw8O48rxy2h3V8G9G6oa85h006M4G04qm16x6041602dG&__hsdp=p0B5n4c8lQ9gCcPFbwj9uUKA4V-5GBuGiK-dUpVEOCEbE2exvQUgpeaju1EwlE1dpQ6804arw&__sjsp=p0B5n4c8lQ9gCcPFbwj9ufF1evxClAFaXz-6uqcFG2W0zEnZe46jyATwq8&__comet_req=7&fb_dtsg=NAfvL_Ia3e1YdP4mvOr-2PezXdcflrTCk6an3vv8DV2O_ozxW9NjPew%3A17853599968089360%3A1765388998&jazoest=26448&lsd=EURIpDDMu0fz4ePVVo-u0e&__spin_r=1031050016&__spin_b=trunk&__spin_t=1765620980&fb_api_caller_class=RelayModern&fb_api_req_friendly_name=PolarisProfilePostsQuery&server_timestamps=true&variables=%7B%22data%22%3A%7B%22count%22%3A12%2C%22include_reel_media_seen_timestamp%22%3Atrue%2C%22include_relationship_info%22%3Atrue%2C%22latest_besties_reel_media%22%3Atrue%2C%22latest_reel_media%22%3Atrue%7D%2C%22username%22%3A%22sportarenastreetball%22%2C%22__relay_internal__pv__PolarisIsLoggedInrelayprovider%22%3Atrue%7D&doc_id=25352076627737294',
        headers_posts
    )
    response = conn.getresponse()
    json_data = json.loads(response.read())
    edges = json_data["data"]["xdt_api__v1__feed__user_timeline_graphql_connection"]["edges"]
    id: int = edges[n]["node"]["pk"]
    title: str = edges[n]["node"]["caption"]["text"]
    return (id, title)

def do_comment_request(comment: str, post_id: int) -> int:
    # post_id = 3784430213149781314
    # post_id = 3785127233443372196
    # post_id = 3785867440086106421

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

        followers = await asyncio.to_thread(get_followers, 50)
        following = await asyncio.to_thread(get_following, 50)
        print(followers)
        print("Length of followers: ", len(followers))
        print(following)
        print("Length of following: ", len(following))
        pool = set(followers).union(set(following))
        
        latest_post_id, post_title = get_nth_latest_postid(n = 1)
        print(f"Latest post id: {latest_post_id} with the title {post_title}")

        global comment_counter
        while True:
            # follower_username = random.choice(followers)
            # following_username = random.choice(following)
            username_to_tag = random.choice(list(pool))
            print(f"Tagging {username_to_tag}...")
            comment: str = AT_SIGN + username_to_tag
            status = await asyncio.to_thread(do_comment_request, comment, latest_post_id)
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
