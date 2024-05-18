import csv
from flask import Flask, jsonify, request
import sqlite3
from flask_cors import CORS
import numpy as np
import os  


app = Flask(__name__,
    static_url_path='',
    static_folder ='frontend/build')
CORS(app)

tweets_path = os.path.abspath("./tweets.csv")


# Load tweets from CSV file
with open(tweets_path, newline="", encoding="utf-8") as csvfile:
    reader = csv.DictReader(csvfile)
    tweets = [row for row in reader]

@app.route("/")


def index():
    return "Hello, World!"


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