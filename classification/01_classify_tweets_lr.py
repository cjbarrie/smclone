from utils import classify_content, process_dataset
from config import pd, openai, datetime, os, json

## Classify static tweets dataset

function_name_tweets = "classify_tweet"  # Note function name cannot contain spaces
function_description_tweets = "This task involves reading some tweets by individual UK MPs or users who are or will later become candidates in the General Election in the UK in 2024. On the basis of its content, you are asked to score the political stance of the text on a scale from Very Left to Very Right."
output_variables_tweets = {
    "type": "object",
    "properties": {
        "tweet": {
            "type": "string",
            "description": "The content of the tweet to be classified."
        },
        "code": {
            "type": "string",
            "enum": ["Very left", "Somewhat left", "Neither left nor right", "Somewhat right", "Very right"],
            "description": "You are asked to give your best judgment of how left or right wing the text is. If you think it expresses a very right-wing stance, label as \"Very right\" for political leaning (and vice versa). If you think it has a stance that is left-wing, but not very left-wing, label as \"Somewhat left (and vice versa).\" If you believe the text expresses a centrist stance or does not express any clear position, you should label as \"Neither left nor right\"."
        }
    },
    "required": ["tweet", "code"]
}

# # Load the first dataset
tweets_pre_election = pd.read_csv("/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered_pre-election.csv")

# # Sample 10 rows
# tweets_pre_election_sample = tweets_pre_election.sample(n=10, random_state=1)

text_column = 'text'  # The name of the column in the DataFrame containing the content to classify
output_csv_pre_election = "/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered_classified_pre-election.csv"

# Process the subsample
processed_dfsamp_static = process_dataset(
    tweets_pre_election, 
    classify_content, 
    output_variables_tweets, 
    function_description_tweets, 
    function_name_tweets, 
    text_column,
    output_csv_pre_election
)

# Load the second dataset
tweets_election = pd.read_csv("/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered_election.csv", low_memory=False)

# # Sample 10 rows
# tweets_election_sample = tweets_election.sample(n=10, random_state=1)

text_column = 'full_text'  # The name of the column in the DataFrame containing the content to classify
output_csv_election = "/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered_classified_election.csv"

# Process the subsample
processed_dfsamp_static = process_dataset(
    tweets_election, 
    classify_content, 
    output_variables_tweets, 
    function_description_tweets, 
    function_name_tweets, 
    text_column,
    output_csv_election
)
