import pandas as pd
import json
from tqdm import tqdm

# Parameters
json_file_path = "/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/2024-06-12__user_timeline__uk-political-candidates.json"
chunk_size = 100000  # Number of lines to read at a time

# Define the columns you want to keep
columns_to_keep = [
    'created_at', 'id', 'id_str', 'text', 'truncated', 'source', 'in_reply_to_status_id', 
    'in_reply_to_status_id_str', 'in_reply_to_user_id', 'in_reply_to_user_id_str', 
    'in_reply_to_screen_name', 'geo', 'coordinates', 'place', 'contributors', 
    'is_quote_status', 'retweet_count', 'favorite_count', 'favorited', 'retweeted', 
    'lang', 'smapp_timestamp', 'entities.hashtags', 'entities.symbols', 'entities.user_mentions', 
    'entities.urls', 'user.id', 'user.id_str', 'user.name', 'user.screen_name', 'user.location', 
    'user.description', 'user.url', 'user.entities.description.urls', 'user.protected', 
    'user.followers_count', 'user.friends_count', 'user.listed_count', 'user.created_at', 
    'user.favourites_count', 'user.utc_offset', 'user.time_zone', 'user.geo_enabled', 
    'user.verified', 'user.statuses_count', 'user.lang', 'user.contributors_enabled', 
    'user.is_translator', 'user.is_translation_enabled', 'user.profile_background_color', 
    'user.profile_background_image_url', 'user.profile_background_image_url_https', 
    'user.profile_background_tile', 'user.profile_image_url', 'user.profile_image_url_https', 
    'user.profile_banner_url', 'user.profile_link_color', 'user.profile_sidebar_border_color', 
    'user.profile_sidebar_fill_color', 'user.profile_text_color', 'user.profile_use_background_image', 
    'user.has_extended_profile', 'user.default_profile', 'user.default_profile_image', 
    'user.following', 'user.follow_request_sent', 'user.notifications', 'user.translator_type', 
    'user.withheld_in_countries', 'possibly_sensitive'
]

# Initialize an empty list to store the processed chunks
tweets_list = []

# Read the JSON file in chunks
with open(json_file_path, 'r') as file:
    chunk = []
    for line in tqdm(file, total=sum(1 for _ in open(json_file_path, 'r')), desc="Processing lines"):
        chunk.append(line)
        if len(chunk) >= chunk_size:
            # Process the chunk
            chunk_data = [json.loads(line) for line in chunk]
            chunk_df = pd.json_normalize(chunk_data)
            chunk_df = chunk_df[columns_to_keep]
            tweets_list.append(chunk_df)
            chunk = []

    # Process any remaining lines
    if chunk:
        chunk_data = [json.loads(line) for line in chunk]
        chunk_df = pd.json_normalize(chunk_data)
        chunk_df = chunk_df[columns_to_keep]
        tweets_list.append(chunk_df)

# Concatenate all chunks into a single DataFrame
tweets = pd.concat(tweets_list, ignore_index=True)

# Convert 'created_at' to datetime format
tweets['created_at'] = pd.to_datetime(tweets['created_at'], format='%a %b %d %H:%M:%S +0000 %Y')

# Filter tweets to include only those between May 22, 2023, and May 22, 2024
tweets = tweets[(tweets['created_at'] < pd.Timestamp('2024-05-22')) & 
                                  (tweets['created_at'] >= pd.Timestamp('2023-05-22'))]

# Convert to 'dd-mm-yyyy' format
tweets['created_at'] = tweets['created_at'].dt.strftime('%d-%m-%Y')

# Save the filtered DataFrame to a new CSV file
tweets.to_csv("/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_pre-election_ALL.csv", index=False)
