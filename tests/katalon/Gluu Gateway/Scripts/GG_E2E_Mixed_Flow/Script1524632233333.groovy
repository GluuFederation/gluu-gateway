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
import com.kms.katalon.core.testobject.RequestObject as RequestObject
import groovy.json.JsonSlurper as JsonSlurper
import com.kms.katalon.core.testobject.TestObjectProperty as TestObjectProperty
import org.apache.http.client.methods.HttpGet as HttpGet
import org.apache.http.client.methods.HttpUriRequest as HttpUriRequest
import org.apache.http.client.HttpClient as HttpClient
import org.apache.http.impl.client.DefaultHttpClient as DefaultHttpClient
import org.apache.http.HttpResponse as HttpResponse
import org.apache.http.message.BasicHeader as BasicHeader
import org.apache.http.util.EntityUtils as EntityUtils

def env = TestDataFactory.findTestData('Data Files/dev1TestData')

def host = env.getValue('Value', 1)

def username = env.getValue('Value', 2)

def password = env.getValue('Value', 3)

def api_host = new Random().nextInt() + 'mix.example.com'

def api_path = ''

def upstream_host = 'https://www.gluu.org'

def uma_path = '/docs/ce/3.1.2/'

WebUI.openBrowser('')

WebUI.navigateToUrl(('https://' + host) + ':1338/#!/login')

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/button_Login'))

WebUI.setText(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_oxAuth - Login/input_loginFormusername'), 
    'michal')

WebUI.setText(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_oxAuth - Login/input_loginFormpassword'), 
    'secret')

WebUI.sendKeys(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_oxAuth - Login/input_loginFormpassword'), 
    Keys.chord(Keys.ENTER))

WebUI.delay(3, FailureHandling.STOP_ON_FAILURE)

WebUI.maximizeWindow()

WebUI.click(findTestObject('Page_Gluu Gateway/a_APIS'))

WebUI.click(findTestObject('Page_Gluu Gateway/a_Add New Api'))

WebUI.delay(3)

WebUI.setText(findTestObject('Page_Gluu Gateway/input_form-control ng-pristine'), 'mix_api' + new Random().nextInt())

WebUI.setText(findTestObject('Page_Gluu Gateway (1)/input_form-control ng-pristine'), api_host)

WebUI.setText(findTestObject('Page_Gluu Gateway/input_form-control ng-untouche'), api_path)

WebUI.setText(findTestObject('Page_Gluu Gateway/input_form-control ng-untouche_1'), 'GET')

WebUI.setText(findTestObject('Page_Gluu Gateway/input_form-control ng-pristine_1'), upstream_host)

WebUI.scrollToElement(findTestObject('Page_Gluu Gateway (2)/button_Submit API'), 5)

WebUI.click(findTestObject('Page_Gluu Gateway/button_Submit API'))

WebUI.click(findTestObject('Page_Gluu Gateway/div_APIs'))

WebUI.click(findTestObject('Page_Gluu Gateway/a_Plugins'))

WebUI.click(findTestObject('Page_Gluu Gateway/button_add plugin'))

WebUI.click(findTestObject('Page_Gluu Gateway/a_Custom'))

WebUI.click(findTestObject('Page_Gluu Gateway/button_btn btn-link btn-icon b'))

WebUI.click(findTestObject('Page_Gluu Gateway/button_add plugin_1'))

WebUI.click(findTestObject('Page_Gluu Gateway/i_mdi mdi-close'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway (1)/a_APIS'))

WebUI.delay(3)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway (1)/a_Security'))

WebUI.delay(3)

WebUI.setText(findTestObject('Page_Gluu Gateway (2)/input_path0'), uma_path)

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

WebUI.delay(5)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/span_CONSUMERS'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/button_Create consumer'))

WebUI.setText(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/input_form-control ng-pristine'), 
    'mix_consumer' + new Random().nextInt())

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/button_Submit Consumer'))

WebUI.delay(5)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/strong_new_consumer'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/uib-tab-heading_CREDENTIALS'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/a_OAUTH2'))

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/button_create credentials'))

WebUI.scrollToElement(findTestObject('Page_Gluu Gateway (7)/span_'), 5)

WebUI.click(findTestObject('Page_Gluu Gateway (7)/span_'))

WebUI.setText(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/input_form-control ng-pristine'), 
    'mix')

WebUI.delay(10)

WebUI.scrollToElement(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/button_Submit'), 
    0)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/Page_Gluu Gateway/button_Submit'))

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

//-----------Get customer token----------------------
RequestObject request = findTestObject('get token')

request.setHttpBody(((((('{"oxd_id":"' + oxdId) + '","client_id":"') + clientId) + '","client_secret":"') + clientSecret) + 
    '","op_host":"https://ce-dev6.gluu.org", "scope":["openid","uma_protection"]}')

response = WS.sendRequest(request)

def parsedResp = parser.parseText(response.getResponseBodyContent())

def accessToken = parsedResp.get('data').get('access_token')

//------------------RequestNoTokenAPI ----------------
HttpUriRequest apiNoTokenRequest = new HttpGet((('http://' + host) + ':8000') + uma_path)

apiNoTokenRequest.addHeader(new BasicHeader('Authorization', ""))

apiNoTokenRequest.addHeader(new BasicHeader('Host', api_host))

HttpClient noTokenClient = new DefaultHttpClient()

HttpResponse httpNoTokenResponse = noTokenClient.execute(apiNoTokenRequest)

//def body = EntityUtils.toString(httpResponse.getEntity(),"utf-8")
WebUI.verifyEqual(httpNoTokenResponse.getStatusLine().statusCode, 403)

//------------------RequestInvalidTokenAPI ----------------
HttpUriRequest apiInvalidTokenRequest = new HttpGet((('http://' + host) + ':8000') + uma_path)

apiInvalidTokenRequest.addHeader(new BasicHeader('Authorization', 'Bearer m' + accessToken))

apiInvalidTokenRequest.addHeader(new BasicHeader('Host', api_host))

HttpClient invalidTokenClient = new DefaultHttpClient()

HttpResponse httpInvalidTokenResponse = invalidTokenClient.execute(apiInvalidTokenRequest)

//def body = EntityUtils.toString(httpResponse.getEntity(),"utf-8")
WebUI.verifyEqual(httpInvalidTokenResponse.getStatusLine().statusCode, 401)

//------------------RequestAPI ----------------
HttpUriRequest apiRequest = new HttpGet((('http://' + host) + ':8000') + uma_path)

apiRequest.addHeader(new BasicHeader('Authorization', 'Bearer ' + accessToken))

apiRequest.addHeader(new BasicHeader('Host', api_host))

HttpClient client = new DefaultHttpClient()

HttpResponse httpResponse = client.execute(apiRequest)

def body = EntityUtils.toString(httpResponse.getEntity(), 'utf-8')

WebUI.verifyEqual(httpResponse.getStatusLine().statusCode, 200)

