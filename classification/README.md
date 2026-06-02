# Tweet Classification and Timeline Construction

This directory contains the tweet filtering, ideological classification, manual review reconciliation, and final timeline construction code used for the UK and US clone feeds.

## Environment

The OpenAI classification scripts require an API key:

```bash
export OPENAI_API_KEY="..."
```

The API client is configured in `classification/config.py`.

## UK Workflow

1. `00_curate_uk_pre-election_tweets.py`
   - Reads the raw UK candidate timeline export expected at:
     `classification/data/uk/2024-06-12__user_timeline__uk-political-candidates.json`
   - Writes a filtered/truncated pre-election sample.

2. `01_classify_uk_tweets_lr.py`
   - Classifies UK election and pre-election samples using the OpenAI API.
   - Writes classified CSVs under `classification/data/uk/`.

3. `02_curate_uk_classifications.R`
   - Curates classified UK outputs into timeline candidates.

4. `03_get_full_uk_pre-elec_tweets.py`
   - Reconstructs the full UK pre-election tweet table from the raw JSON export.

5. `04_get_uk_final_timeline.R`
   - Combines manual review and full-text metadata.
   - Writes the final UK feed:
     `classification/data/uk/final/pre-election_to_use_final.csv`

The raw UK line-delimited JSON export is not a generated output of this repository. If it is not present, use the final CSV directly for analyses and clone-feed reproduction.

## US Workflow

1. `05_classify_us_tweets_lr.py`
   - Reads `classification/data/us/usa_tweets.csv`.
   - Filters, truncates, samples, and classifies tweets using the OpenAI API.
   - Writes `classification/data/us/usa_tweets_filtered.csv` and `classification/data/us/usa_tweets_filtered_classified.csv`.

2. `06_curate_us_classifications.R`
   - Curates classified US tweets into manual-review candidates.

3. `07_get_us_final_timeline.R`
   - Combines three manual-coding files and full tweet text.
   - Writes `classification/data/us/final/usa_timeline_final.csv`.

4. `08_extend_us_tweets.py`
   - Adds expanded metadata to the final US timeline.
   - Writes `classification/data/us/final/usa_timeline_final_extended.csv`.

## Final Feed Files

The final feed files used in the study clone interface are:

- UK: `classification/data/uk/final/pre-election_to_use_final.csv`
- US: `classification/data/us/final/usa_timeline_final_extended.csv`

These are the files to use when reproducing the clone feed without rerunning upstream collection and LLM classification.
