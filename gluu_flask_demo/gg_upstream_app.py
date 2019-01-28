from flask import Flask, jsonify, request
import time
app = Flask(__name__)

@app.route('/posts')
def posts():
    return jsonify({'location': request.url, 'time':time.ctime(),"message": "I am a test flask-api for Gluu Gateway"})


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, ssl_context='adhoc')
