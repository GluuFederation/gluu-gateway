#!/usr/bin/python

init=False
api_url="https://kong.example.com/demo/protected1"
gg_base_url = "https://demo.gluu.org"
api_path = "dove"

# Client calls API without RPT token



# Client calls AS UMA /token endpoint with permission ticket and client creds

# Client calls API Gateway with RPT token

# No RPT for you!  Go directly to Claims Gathering!
# AS returns needs_info with clailms gathering URI, which the user should
# put in his browser. Link shortner would be nice if the user has to type it in.

# Here is my PCT token!
# Client attempts to get RPT at UMA /token endpoint, this time presenting the
# PCT
