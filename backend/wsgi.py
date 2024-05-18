from backend.app import app as app

if __name__ == "__main__":
    app.run()


import os
from backend.app import app as application

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    application.run(host='0.0.0.0', port=port)


    