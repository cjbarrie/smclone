# Clone Interface Frontend

This directory contains the React frontend for the social-media clone interface used in the studies.

## Install

From this directory:

```bash
npm install
```

## Run

Start the frontend development server:

```bash
npm start
```

By default, the app opens at `http://localhost:3000` and expects the Flask backend API to be available at `http://localhost:5001`.

To run the backend and frontend together from the repository root:

```bash
npm run start
```

## Configuration

The frontend reads optional configuration from environment variables:

- `REACT_APP_API_BASE_URL`: backend API URL. Defaults to `http://localhost:5001`.
- `REACT_APP_POSTHOG_KEY`: PostHog project key.
- `REACT_APP_POSTHOG_HOST`: PostHog host URL.
- `REACT_APP_QUALTRICS_URL`: redirect URL used at the end of the study flow.

See the repository-level `.env.example` for example values.

## Build

Create a production build:

```bash
npm run build
```
