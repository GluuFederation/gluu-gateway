import json

def displayPageHeader():
    print "HTTP/1.0 200 OK"
    print "Content-type: text/html\n\n"
    print "<head>"
    print "<title>Gluu Gateway Demo</title>"
    print "<meta charset=\"utf-8\">"
    print "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    print "<link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css\">"
    print "<script src=\"https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js\"></script>"
    print "<script src=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js\"></script>"
    print "</head>"
    print "<body style=\"top: 8rem;position: absolute;\">"
    print "<header style=\"position: fixed;top: 0; right: 0;left: 0;height: 6.6rem;background-color: #223243;color: #fff;\">"
    print "<img style=\"display: inline-block;\" src='/resource/gluu-gateway.png' />"
    print "<h3 style=\"display: inline-block; float:right;\">DEMO</h3>"
    print "</header>"

def displayResponse(response, request):
    body = "<table style=\"width: 100%; table-layout: fixed\"><tr><td width=\"200px\">Request url:</td><td>" + response.url + "</td></tr>"
    body += "<tr><td>Request headers:</td><td>" + str(response.request.headers) + "</td></tr>"
    body += "<tr><td>Request body:</td><td> <pre>" + json.dumps(request,indent=4) + "</pre></td></tr>"
    body += "<tr><td>Response status:</td><td>" + str(response.status_code) + "</td></tr>"
    body += "<tr><td>Response headers:</td><td>" + str(response.headers) + "</td></tr>"
    body += "<tr><td>Response body:</td><td> <pre>" + json.dumps(response.json(),indent=4) + "</pre></td></tr></table>"
    displayPanel(body)

def displayActionName(name):
    print("<h3 style=\"padding-left:20px;\">"+name+"</h3></br>")


def displayPanel(body):
    print "<div style=\"padding: 20px; margin:20px;\" class=\" panel panel-default\">"
    print body
    print "</div>"