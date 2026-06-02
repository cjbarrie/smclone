from utils import classify_content, process_dataset
from config import pd, openai, datetime, os, json
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent

## Classify static tweets dataset

function_name_tweets = "classify_tweet"  # Note function name cannot contain spaces
function_description_tweets = "This task involves reading some tweets by individual US legislators. On the basis of its content, you are asked to score the political stance of the text on a scale from Very Left to Very Right."
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
tweets = pd.read_csv(SCRIPT_DIR / "data/us/usa_tweets.csv")

# Further filter to keep only tweets longer than 200 characters
tweets_filtered = tweets[tweets['text'].str.len() > 100]

# Function to truncate text and add ellipses and "Read more"
def truncate_text(text):
    return text[:100] + '... Read more'

# Apply the function to the full_text column
tweets_filtered['text'] = tweets_filtered['text'].apply(truncate_text)

# Save the filtered DataFrame to a new CSV file
tweets_filtered.to_csv(SCRIPT_DIR / "data/us/usa_tweets_filtered.csv", index=False)

# Sample 10,000 rows and shuffle them
tweets_us = tweets_filtered.sample(n=10000, random_state=1).reset_index(drop=True)

text_column = 'text'  # The name of the column in the DataFrame containing the content to classify
output_csv_us = SCRIPT_DIR / "data/us/usa_tweets_filtered_classified.csv"

# Process the subsample
processed_dfsamp_static = process_dataset(
    tweets_us, 
    classify_content, 
    output_variables_tweets, 
    function_description_tweets, 
    function_name_tweets, 
    text_column,
    output_csv_us
)
