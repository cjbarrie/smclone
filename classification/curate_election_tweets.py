import pandas as pd

# Path to the input and output CSV files
input_csv = "/Users/cbarrie6/Dropbox/nyu_projects/ukgetweets/data/processed/mptweets_all.csv"
output_csv = "/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered_election.csv"

# Function to truncate text and add ellipses and "Read more"
def truncate_text(text):
    return text[:100] + '... Read more'

# Initialize the CSV writer
with open(output_csv, 'w', encoding='utf-8') as f_out:
    # Write the header for the desired columns
    f_out.write("created_at,id_str,full_text\n")

    # Process the CSV in chunks
    chunksize = 10000
    for chunk in pd.read_csv(input_csv, chunksize=chunksize, encoding='utf-8', on_bad_lines='skip'):
        # Convert 'created_at' to datetime using the appropriate format
        chunk['created_at'] = pd.to_datetime(chunk['created_at'], format='%a %b %d %H:%M:%S +0000 %Y')

        # Filter to keep only tweets after May 22, 2024
        chunk = chunk[chunk['created_at'] > pd.Timestamp('2024-05-22')]

        # Filter to keep only original tweets (i.e., not retweets)
        chunk = chunk[chunk['is_retweet'] == False]

        # Further filter to keep only tweets longer than 100 characters
        chunk = chunk[chunk['full_text'].str.len() > 100]

        # Apply the truncation function to the full_text column
        chunk['full_text'] = chunk['full_text'].apply(truncate_text)

        # Clean the text to remove any problematic characters
        chunk['full_text'] = chunk['full_text'].str.replace(r'[^\x00-\x7F]+', '', regex=True)

        # Retain only the required columns
        chunk = chunk[['created_at', 'id_str', 'full_text']]

        # Append the chunk to the output CSV
        chunk.to_csv(f_out, index=False, header=False, encoding='utf-8')

# Read the output CSV and sample 10,000 tweets
tweets_filtered = pd.read_csv(output_csv, encoding='utf-8', low_memory=False)

# Filter again to ensure only tweets after May 22, 2024, are included
tweets_filtered['created_at'] = pd.to_datetime(tweets_filtered['created_at'])
tweets_filtered = tweets_filtered[tweets_filtered['created_at'] > pd.Timestamp('2024-05-22')]

# Sample 10,000 tweets
tweets_filtered_sampled = tweets_filtered.sample(n=10000, random_state=1)

# Save the sampled tweets to a new CSV file
tweets_filtered_sampled.to_csv(output_csv, index=False, encoding='utf-8')
