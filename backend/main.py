from flask import Flask, jsonify, request
import sqlite3
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route("/")
def index():
    return "Hello, World!"

@app.route("/users", methods=["POST"])
def create_user():
    name = request.json.get("name")
    email = request.json.get("email")

    if not name or not email:
        return jsonify({"error": "Both name and email are required"}), 400

    conn = sqlite3.connect("users.db")
    c = conn.cursor()
    c.execute("INSERT INTO users (name, email) VALUES (?, ?)", (name, email))
    user_id = c.lastrowid
    conn.commit()
    conn.close()

    return jsonify({"id": user_id, "name": name, "email": email}), 201

if __name__ == "__main__":
    app.run(debug=True)
