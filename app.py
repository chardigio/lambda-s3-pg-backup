import json
import subprocess

print("Loading my function")


def handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    subprocess.run("sh backup.sh".split(" "))
    print("Process complete.")
    return 0
