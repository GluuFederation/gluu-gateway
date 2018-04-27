import static com.kms.katalon.core.checkpoint.CheckpointFactory.findCheckpoint
import static com.kms.katalon.core.testcase.TestCaseFactory.findTestCase
import static com.kms.katalon.core.testdata.TestDataFactory.findTestData
import static com.kms.katalon.core.testobject.ObjectRepository.findTestObject
import com.kms.katalon.core.checkpoint.Checkpoint as Checkpoint
import com.kms.katalon.core.checkpoint.CheckpointFactory as CheckpointFactory
import com.kms.katalon.core.mobile.keyword.MobileBuiltInKeywords as MobileBuiltInKeywords
import com.kms.katalon.core.mobile.keyword.MobileBuiltInKeywords as Mobile
import com.kms.katalon.core.model.FailureHandling as FailureHandling
import com.kms.katalon.core.testcase.TestCase as TestCase
import com.kms.katalon.core.testcase.TestCaseFactory as TestCaseFactory
import com.kms.katalon.core.testdata.TestData as TestData
import com.kms.katalon.core.testdata.TestDataFactory as TestDataFactory
import com.kms.katalon.core.testobject.ObjectRepository as ObjectRepository
import com.kms.katalon.core.testobject.TestObject as TestObject
import com.kms.katalon.core.webservice.keyword.WSBuiltInKeywords as WSBuiltInKeywords
import com.kms.katalon.core.webservice.keyword.WSBuiltInKeywords as WS
import com.kms.katalon.core.webui.keyword.WebUiBuiltInKeywords as WebUiBuiltInKeywords
import com.kms.katalon.core.webui.keyword.WebUiBuiltInKeywords as WebUI
import internal.GlobalVariable as GlobalVariable
import org.openqa.selenium.Keys as Keys
import org.openqa.selenium.WebElement as WebElement
import org.openqa.selenium.interactions.Actions as Actions
import com.kms.katalon.core.testobject.RequestObject as RequestObject
import groovy.json.JsonSlurper as JsonSlurper
import org.junit.After as After
import com.kms.katalon.core.testobject.TestObjectProperty as TestObjectProperty
import com.kms.katalon.core.testobject.RestRequestObjectBuilder as RestRequestObjectBuilder
import org.apache.http.client.methods.HttpGet as HttpGet
import org.apache.http.client.methods.HttpUriRequest as HttpUriRequest
import org.apache.http.client.HttpClient as HttpClient
import org.apache.http.impl.client.DefaultHttpClient as DefaultHttpClient
import org.apache.http.HttpResponse as HttpResponse
import org.apache.http.message.BasicHeader as BasicHeader
import com.kms.katalon.core.testdata.TestDataFactory
import org.apache.http.util.EntityUtils

def env = TestDataFactory.findTestData("Data Files/dev1TestData")
def host = env.getValue("Value", 1)
def username = env.getValue("Value", 2)
def password = env.getValue("Value", 3)

def api_host = new Random().nextInt()+'uma.example.com'

WebUI.openBrowser('')

WebUI.navigateToUrl('https://'+host+':1338/#!/login')

WebUI.maximizeWindow()

WebUI.doubleClick(findTestObject('Page_Gluu Gateway (2)/div_Login'))

WebUI.click(findTestObject('Page_Gluu Gateway (2)/button_Login'))

WebUI.delay(5)

WebUI.setText(findTestObject('Page_oxAuth - Login (2)/input_loginFormusername'), username)

WebUI.setText(findTestObject('Page_oxAuth - Login (2)/input_loginFormpassword'), password)

WebUI.click(findTestObject('Page_oxAuth - Login (2)/input_loginFormloginButton'))

WebUI.delay(10)

WebUI.click(findTestObject('Page_Gluu Gateway (1)/Page_Gluu Gateway/a_APIS'))

WebUI.click(findTestObject('Page_Gluu Gateway (1)/Page_Gluu Gateway/a_Add New Api'))

WebUI.setText(findTestObject('Page_Gluu Gateway/input_form-control ng-pristine'), 'new_api' + new Random().nextInt())

WebUI.setText(findTestObject('Page_Gluu Gateway (1)/input_form-control ng-pristine'), api_host)

WebUI.setText(findTestObject('Page_Gluu Gateway/input_form-control ng-untouche'), '')

WebUI.setText(findTestObject('Page_Gluu Gateway/input_form-control ng-untouche_1'), 'GET')

WebUI.setText(findTestObject('Page_Gluu Gateway/input_form-control ng-pristine_1'), 'https://gluu.org')

WebUI.click(findTestObject('Page_Gluu Gateway/button_Submit API'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway (3)/i_mdi mdi-pencil'))

WebUI.click(findTestObject('Page_Gluu Gateway (2)/a_Plugins'))

WebUI.click(findTestObject('Page_Gluu Gateway (2)/button_add plugin'))

WebUI.click(findTestObject('Page_Gluu Gateway (2)/a_Custom'))

WebUI.click(findTestObject('Page_Gluu Gateway (2)/div_gluu oauth2 client auth'))

WebUI.click(findTestObject('Page_Gluu Gateway (2)/button_btn btn-link btn-icon b'))

WebUI.click(findTestObject('Page_Gluu Gateway (2)/button_add plugin_1'))

WebUI.click(findTestObject('Page_Gluu Gateway (2)/i_mdi mdi-close'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway (1)/a_APIS'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway (1)/a_Security'))

WebUI.delay(3)

WebUI.setText(findTestObject('Page_Gluu Gateway (2)/input_path0'), '/docs/')

WebUI.setText(findTestObject('Page_Gluu Gateway (2)/input_input ng-pristine ng-unt'), 'http://photoz.example.com/dev/actions/view')

WebUI.delay(1)

WebUI.clickOffset(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway (1)/button_Add'), 
    50, -400)

WebUI.delay(1)

WebUI.click(findTestObject('Page_Gluu Gateway (6)/input_condition000'))

WebUI.clickOffset(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway (1)/button_Add'), 
    50, -400)

WebUI.delay(1)

WebUI.scrollToElement(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway (1)/button_Add'), 
    0)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway (1)/button_Add'))

WebUI.delay(15)

WebUI.click(findTestObject('Page_Gluu Gateway (5)/a_APIS'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway (5)/a_Security'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway (5)/td_84164f52-7986-406d-87bd-006'))

uma_oxdid = WebUI.getText(findTestObject('Page_Gluu Gateway (5)/td_84164f52-7986-406d-87bd-006'))

WebUI.scrollToElement(findTestObject('Page_Gluu Gateway (5)/i_mdi mdi-eye'), 3)

WebUI.click(findTestObject('Page_Gluu Gateway (5)/i_mdi mdi-eye'))

WebUI.click(findTestObject('Page_Gluu Gateway (5)/span_19CF.B296.532F.83E2000125'))

uma_clientid = WebUI.getText(findTestObject('Page_Gluu Gateway (5)/span_19CF.B296.532F.83E2000125'))

WebUI.scrollToElement(findTestObject('Page_Gluu Gateway (5)/i_mdi mdi-eye_1'), 5)

WebUI.click(findTestObject('Page_Gluu Gateway (5)/i_mdi mdi-eye_1'), FailureHandling.STOP_ON_FAILURE)

WebUI.click(findTestObject('Page_Gluu Gateway (5)/span_b93e0539-ff1e-4b95-81bc-2'))

uma_clientsecret = WebUI.getText(findTestObject('Page_Gluu Gateway (5)/span_b93e0539-ff1e-4b95-81bc-2'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/span_CONSUMERS'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/button_Create consumer'))

WebUI.setText(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/input_form-control ng-pristine'), 
    'new_consumer' + new Random().nextInt())

WebUI.click(findTestObject('Page_Gluu Gateway (4)/button_Submit Consumer'))

WebUI.delay(3)

WebUI.scrollToElement(findTestObject('Page_Gluu Gateway (4)/strong_vs'), 5)

WebUI.click(findTestObject('Page_Gluu Gateway (4)/strong_vs'))

WebUI.click(findTestObject('Page_Gluu Gateway (4)/a_CREDENTIALS'))

WebUI.click(findTestObject('Page_Gluu Gateway (4)/a_OAUTH2'))

WebUI.click(findTestObject('Page_Gluu Gateway (4)/button_create credentials'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway (4)/span_'))

WebUI.delay(3)

WebUI.setText(findTestObject('Page_Gluu Gateway (4)/input_form-control ng-untouche_1'), 'uma')

WebUI.click(findTestObject('Page_Gluu Gateway (4)/div_Create OAuth2'))

WebUI.scrollToElement(findTestObject('Page_Gluu Gateway (4)/button_Submit'), 5)

WebUI.click(findTestObject('Page_Gluu Gateway (4)/button_Submit'))

WebUI.delay(5)

WebUI.waitForElementVisible(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/td_0b98c9ea-11ba-4137-9f66-185'), 
    5)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/td_0b98c9ea-11ba-4137-9f66-185'))

oxdId = WebUI.getText(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/td_0b98c9ea-11ba-4137-9f66-185'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/td_19CF.B296.532F.83E2000125C1'))

clientId = WebUI.getText(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/td_19CF.B296.532F.83E2000125C1'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/td_94bf787c-a42d-4a66-b8d3-41d'))

clientSecret = WebUI.getText(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/td_94bf787c-a42d-4a66-b8d3-41d'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/button_OK'))

WebUI.delay(5)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/a_'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/a_Logout'))

WebUI.closeBrowser()

JsonSlurper parser = new JsonSlurper()

//-------------UMA client accessToken
RequestObject request2 = findTestObject('get token')

request2.setHttpBody(((((('{"oxd_id":"' + uma_oxdid) + '","client_id":"') + uma_clientid) + '","client_secret":"') + uma_clientsecret) + 
    '","op_host":"https://ce-dev6.gluu.org", "scope":["openid","uma_protection"]}')

response = WS.sendRequest(request2)

def parsedResp2 = parser.parseText(response.getResponseBodyContent())

def umaAccessToken = parsedResp2.get('data').get('access_token')

WebUI.verifyNotEqual(umaAccessToken, null)

//-------------customer client accessToken
RequestObject clientRequest = findTestObject('get token')

clientRequest.setHttpBody(((((('{"oxd_id":"' + oxdId) + '","client_id":"') + clientId) + '","client_secret":"') + clientSecret) + 
    '","op_host":"https://ce-dev6.gluu.org", "scope":["openid","uma_protection"]}')

clientResponse = WS.sendRequest(clientRequest)

def clientParsedResp = parser.parseText(clientResponse.getResponseBodyContent())

def customerAccessToken = clientParsedResp.get('data').get('access_token')

WebUI.verifyNotEqual(customerAccessToken, null)

//------------------get ticket ----------------
RequestObject ticketRequest = findTestObject('UmaRsCheckAccess')

ticketRequest.setHttpBody(((('{"oxd_id":"' + uma_oxdid) + '","path":"/docs/","http_method":"GET","protection_access_token":"') + 
    umaAccessToken) + '"}')

ticketRequest.getHttpHeaderProperties().add(new TestObjectProperty('Authorization', null, 'Bearer ' + umaAccessToken))

ticketResponse = WS.sendRequest(ticketRequest)

def ticketParsedResp = parser.parseText(ticketResponse.getResponseBodyContent())

def ticket = ticketParsedResp.get('data').get('ticket')

WebUI.verifyNotEqual(ticket, null)

//------------------get rpt ----------------
RequestObject rptRequest = findTestObject('GetRpt')

rptRequest.setHttpBody(((((('{"oxd_id":"' + oxdId) + '","ticket":"') + ticket) + '","protection_access_token":"') + customerAccessToken) + 
    '"}')

rptRequest.getHttpHeaderProperties().add(new TestObjectProperty('Authorization', null, 'Bearer ' + customerAccessToken))

rptResponse = WS.sendRequest(rptRequest)

def rptParsedResp = parser.parseText(rptResponse.getResponseBodyContent())

def rpt = rptParsedResp.get('data').get('access_token')

WebUI.verifyNotEqual(rpt, null)

//------------------RequestNoTokenAPI ----------------
HttpClient noTokenClient = new DefaultHttpClient()

HttpUriRequest apiNoTokenRequest = new HttpGet('http://'+host+':8000/docs/')

apiNoTokenRequest.addHeader(new BasicHeader('Authorization', 'Bearer m' + rpt))

apiNoTokenRequest.addHeader(new BasicHeader('Host', api_host ))

HttpResponse noTokenHttpResponse = noTokenClient.execute(apiNoTokenRequest)
//def invalidTokenBbody = EntityUtils.toString(invalidTokenHttpResponse.getEntity(),"utf-8")
WebUI.verifyEqual(noTokenHttpResponse.getStatusLine().statusCode, 401)


//------------------RequestInvalidTokenAPI ----------------
HttpClient invalidTokenClient = new DefaultHttpClient()

HttpUriRequest apiInvalidTokenRequest = new HttpGet('http://'+host+':8000/docs/')

apiInvalidTokenRequest.addHeader(new BasicHeader('Authorization', 'Bearer m' + rpt))

apiInvalidTokenRequest.addHeader(new BasicHeader('Host', api_host ))

HttpResponse invalidTokenHttpResponse = invalidTokenClient.execute(apiInvalidTokenRequest)
//def invalidTokenBbody = EntityUtils.toString(invalidTokenHttpResponse.getEntity(),"utf-8")
WebUI.verifyEqual(invalidTokenHttpResponse.getStatusLine().statusCode, 401)


//------------------RequestAPI ----------------

HttpUriRequest apiRequest = new HttpGet('http://'+host+':8000/docs/')

apiRequest.addHeader(new BasicHeader('Authorization', 'Bearer ' + rpt))

apiRequest.addHeader(new BasicHeader('Host', api_host ))

HttpClient client = new DefaultHttpClient()

HttpResponse httpResponse = client.execute(apiRequest)
//def body = EntityUtils.toString(httpResponse.getEntity(),"utf-8")
WebUI.verifyEqual(httpResponse.getStatusLine().statusCode, 200)

