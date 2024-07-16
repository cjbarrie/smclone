import pandas as pd
import json
import random
# Parameters
sample_size = 100000  # Number of random samples to read
json_file_path = "/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/2024-06-12__user_timeline__uk-political-candidates.json"

# First, count the total number of lines in the file
total_lines = sum(1 for _ in open(json_file_path, 'r'))

# Calculate the probability of selecting each line
probability = sample_size / total_lines

# Initialize an empty list to store the sampled tweets
sampled_tweets = []

# Read the JSON file line by line and randomly select lines
with open(json_file_path, 'r') as file:
    for line in file:
        if random.random() < probability:
            try:
                tweet = json.loads(line)
                sampled_tweets.append(tweet)
            except json.JSONDecodeError as e:
                print(f"Error decoding JSON: {e}")

# Normalize the list of JSON objects into a flat table
tweets = pd.json_normalize(sampled_tweets)

# Print all column names
print(list(tweets.columns))

# Filter to keep only tweets that have empty cells for 'retweeted_status.id'
tweets_filtered = tweets[tweets['retweeted_status.id'].isnull()]

# Filter to keep only tweets that are not replies to others
tweets_filtered = tweets_filtered[tweets_filtered['in_reply_to_status_id'].isnull()]

# Further filter to keep only tweets longer than 200 characters
tweets_filtered = tweets_filtered[tweets_filtered['text'].str.len() > 100]

# Function to truncate text and add ellipses and "Read more"
def truncate_text(text):
    return text[:100] + '... Read more'

# Apply the function to the full_text column
tweets_filtered['text'] = tweets_filtered['text'].apply(truncate_text)

# List of columns to retain
columns_to_retain = ['created_at','id_str', 'text']

tweets_filtered = tweets_filtered[columns_to_retain]

# Convert 'created_at' to datetime format
tweets_filtered ['created_at'] = pd.to_datetime(tweets_filtered ['created_at'], format='%a %b %d %H:%M:%S +0000 %Y')

# Filter tweets to include only those between May 22, 2023, and May 22, 2024
tweets_filtered = tweets_filtered[(tweets_filtered['created_at'] < pd.Timestamp('2024-05-22')) & 
                                  (tweets_filtered['created_at'] >= pd.Timestamp('2023-05-22'))]

# Convert to 'dd-mm-yyyy' format
tweets_filtered ['created_at'] = tweets_filtered ['created_at'].dt.strftime('%d-%m-%Y')

# Save the filtered DataFrame to a new CSV file
tweets_filtered.to_csv("/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered_pre-election.csv", index=False)
