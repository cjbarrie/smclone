from utils import classify_content, process_dataset
from config import pd, openai, datetime, os, json

## Classify static tweets dataset

function_name_tweets= "classify_tweet" # Note function name cannot contain spaces
function_description_tweets = "This task involves reading some tweets by UK MPs. On the basis of its content, you are asked to score the political stance of the text on a scale from Very Left to Very Right."
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
            "description": "You will be asked to give your best judgment of how left or right wing the text is. If you think it expresses a very right-wing stance, label as \"Very right\" for political leaning (and vice versa). If you think it has a stance that is left-wing, but not very left-wing, label as \"Somewhat left (and vice versa).\" If you believe the text expresses a centrist stance or does not express any clear position, you should label as \"Neither left nor right\"."
        }
    },
    "required": ["tweet", "code"]
}

tweets = pd.read_csv("/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered.csv")

text_column = 'full_text'  # The name of the column in the DataFrame containing the content to classify
output_csv = "/Users/cbarrie6/Dropbox/nyu_projects/smclone/classification/data/tweets_sample_filtered_classified.csv"

# Process the subsample
processed_dfsamp_static = process_dataset(
    tweets, 
    classify_content, 
    output_variables_tweets, 
    function_description_tweets, 
    function_name_tweets, 
    text_column,
    output_csv
)

# Print the text and classification for each tweet
for index, row in processed_dfsamp_static.iterrows():
    print(f"Tweet: {row['full_text']}")
    print(f"Classification: {row['code_gpt']}\n")