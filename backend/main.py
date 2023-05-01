from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///twitter_clone.db"
db = SQLAlchemy(app)

# Add your database models here

@app.route("/")
def hello():
    return "Hello, this is the Twitter clone backend!"

# Add your API routes here

if __name__ == "__main__":
    app.run(debug=True)
