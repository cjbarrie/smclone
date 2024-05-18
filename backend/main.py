import csv
from flask import Flask, jsonify, request, send_from_directory
import sqlite3
from flask_cors import CORS
import numpy as np
import os  


app = Flask(__name__,
    static_url_path='',
    static_folder ='frontend/build')
CORS(app)

absolute_path = os.path.abspath("tweets.csv")


import os

# Get the absolute path to the CSV file relative to the current file's directory
tweets_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'tweets.csv'))


frontend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'frontend/build'))

# Load tweets from CSV file
with open(tweets_path, newline="", encoding="utf-8") as csvfile:
    reader = csv.DictReader(csvfile)
    tweets = [row for row in reader]


@app.route("/")

def index():
    return frontend_path
    # return send_from_directory(frontend_path, 'index.html')


@app.route("/tweets", methods=["GET"])
def get_tweets():

    with open(tweets_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile)
        next(reader, None)  # skip the header row
        for tweet in reader:
            tweets.append({
                "id": tweet[1],
                "user_id": tweet[2],
                "username": tweet[6],
                "name": tweet[7],
                "tweet": tweet[3],
                "retweets_count": int(tweet[4]),  # Convert retweets count to integer
                "likes_count": int(tweet[5]),     # Convert likes count to integer
                "profile_image_url": tweet[8]
            })


    np.random.shuffle(tweets)

    return jsonify(tweets)


if __name__ == "__main__":
    app.run(debug=True)