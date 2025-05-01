# extend_tweets.py

from config import pd
from utils import process_extensions

# 1. Load your CSV (with columns 'text_truncated' and 'classification')
df = pd.read_csv("data/us/final/usa_timeline_final.csv")

# 2. Kick off the concurrent extension job
df_extended = process_extensions(
    dfsamp=df,
    text_column="text_truncated",
    classification_column="classification",
    output_column="tweet_gpt_extended",
    output_csv="data/us/final/usa_timeline_final_extended.csv",
    max_workers=5
)
