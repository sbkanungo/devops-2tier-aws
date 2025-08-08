from flask import Flask, request, jsonify
import sqlite3

app = Flask(__name__)

# Create database if not exists
conn = sqlite3.connect('data.db', check_same_thread=False)
c = conn.cursor()
c.execute('''CREATE TABLE IF NOT EXISTS users (name TEXT, email TEXT)''')
conn.commit()

@app.route("/save", methods=["POST"])
def save():
    data = request.get_json()
    name = data.get("name")
    email = data.get("email")
    if name and email:
        c.execute("INSERT INTO users (name, email) VALUES (?, ?)", (name, email))
        conn.commit()
        return jsonify({"message": "Data saved"}), 200
    return jsonify({"error": "Invalid input"}), 400

@app.route("/users", methods=["GET"])
def users():
    c.execute("SELECT * FROM users")
    rows = c.fetchall()
    return jsonify(rows)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
