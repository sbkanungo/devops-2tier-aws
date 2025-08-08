from flask import Flask, request, render_template_string
import requests

app = Flask(__name__)

html = """
<h2>User Form</h2>
<form method="post">
  Name: <input name="name"><br><br>
  Email: <input name="email"><br><br>
  <input type="submit">
</form>
{% if message %}
<p>{{ message }}</p>
{% endif %}
"""

@app.route("/", methods=["GET", "POST"])
def index():
    message = ""
    if request.method == "POST":
        name = request.form.get("name")
        email = request.form.get("email")
        backend_url = "http://<BACKEND_PRIVATE_IP>:5000/save"  # replace with backend private IP from Terraform output
        try:
            r = requests.post(backend_url, json={"name": name, "email": email})
            if r.status_code == 200:
                message = "Data saved successfully!"
            else:
                message = "Failed to save data!"
        except:
            message = "Backend not reachable!"
    return render_template_string(html, message=message)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
