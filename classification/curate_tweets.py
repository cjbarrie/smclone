import pandas as pd

tweets = pd.read_csv("/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample.csv")

# Filter to keep only retweets
tweets_filtered = tweets[tweets['is_retweet'] == False]

# Further filter to keep only tweets longer than 200 characters
tweets_filtered = tweets_filtered[tweets_filtered['full_text'].str.len() > 200]

# Function to truncate text and add ellipses and "Read more"
def truncate_text(text):
    return text[:200] + '... Read more'

# Apply the function to the full_text column
tweets_filtered['full_text'] = tweets_filtered['full_text'].apply(truncate_text)

tweets_filtered.to_csv("/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered.csv", index=False)

