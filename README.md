# Information Diets Are More Diverse in Attention Than in Engagement

This repository contains replication materials for the article "Information diets are more diverse in attention than in engagement."

This repository contains the social-media clone application, tweet classification and curation code, cleaned study data, and analysis scripts used to reproduce the empirical and simulation results reported in the article.

## Repository Structure

- `frontend/`: React implementation of the clone interface.
- `backend/`: Flask backend used to serve timeline posts to the clone interface.
- `classification/`: tweet filtering, LLM classification, manual-coding reconciliation, and final timeline construction.
- `analysis/`: PostHog cleaning scripts, regression/meta-analysis scripts, robustness scripts, and generated figure/table outputs.
- `prereg/`: preregistration materials.
- `reviews/`: review and revision materials.

## Requirements

Python and app dependencies:

```bash
pip install -r requirements.txt
npm install
cd frontend && npm install
```

R package requirements are listed in `analysis/README.md`. A fresh R environment should install those packages before running the analysis pipeline.

OpenAI-based classification scripts require an API key:

```bash
export OPENAI_API_KEY="..."
```

See `.env.example` for optional frontend and app configuration values.

## Reproducing the Analysis

From the repository root:

```bash
Rscript analysis/run_all.R
```

This runs the data-cleaning scripts, main models, attention-check robustness models, zero-expanded exposure robustness models, and user-click distribution analysis. Outputs are written to:

- `analysis/plots/`
- `analysis/tables/`

The reported article results correspond to the generated files in these output directories.

## Reproducing Tweet Classification and Timeline Construction

See `classification/README.md` for the classification workflow and expected inputs/outputs. The final feed files used by the clone interface are included in the repository, while some upstream collection inputs are described for users who want to rerun the full classification pipeline.

## Inspecting the Clone App

Run the backend and frontend together:

```bash
npm run start
```

Run the backend only:

```bash
cd backend
export FLASK_APP=main.py
flask run --port 5001
```

Run the frontend only:

```bash
cd frontend
npm start
```

The React app reads optional configuration from environment variables:

- `REACT_APP_API_BASE_URL`
- `REACT_APP_POSTHOG_KEY`
- `REACT_APP_POSTHOG_HOST`
- `REACT_APP_QUALTRICS_URL`
