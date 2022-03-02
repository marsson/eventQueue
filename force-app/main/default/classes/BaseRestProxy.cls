
@SuppressWarnings('PMD.AvoidGlobalModifier')
global virtual with sharing class BaseRestProxy {

    private static final String JSON_CONTENT_TYPE = 'application/json; charset=UTF-8';
    private static final String URL_CONTENT_TYPE = 'application/x-www-form-urlencoded;';

    private String callout;
    private String uriString;
    private Http http = new Http();

    protected HttpRequest httpRequest {get; set;}

    protected HttpResponse httpResponse {get; set;}


    private String namedCredentialName;
    private String method;


    public BaseRestProxy() {
        uriString='';
        http = new Http();
        httpRequest = new HttpRequest();
        httpRequest.setTimeout(120000);
    }


    public BaseRestProxy(Event_Configuration__mdt config) {
        this();
        namedCredentialName = config.NamedCredencial__c;
        method = config.method__c;
    }

    virtual
    global void setup() {

        System.debug(' --------- Setup endpoint to Named Credential ' + namedCredentialName );

        //this.httpRequest.setEndpoint( 'callout:'+namedCredentialName );

        if(EventQueueHelper.isNamedCredencialValid(namedCredentialName)==false && !Test.isRunningTest()){
        throw new IntegrationException('Invalid Named Credential '+ namedCredentialName);
        }
        this.callout='callout:'+namedCredentialName;
        System.debug('CALLOUT='+this.callout);
        this.httpRequest.setMethod( method );
        this.httpRequest.setHeader('Content-Type', JSON_CONTENT_TYPE);
        this.httpRequest.setEndpoint(this.callout);

    }



    virtual
    global String get( Map<String, String> uriParameters) {

        this.httpRequest.setMethod( 'GET' );

        setup();
        setUriParameters ( uriParameters );

        this.httpRequest.setEndpoint(this.callout+this.uriString);

        httpResponse = tryToSend (this.httpRequest);

        return httpResponse.getBody();

    }

    virtual
    global String send( Object obj ) {

        setup();

        setBody (obj);

        httpResponse = tryToSend (this.httpRequest);

        return httpResponse.getBody();

    }
    virtual
    global String send( String aString ) {

        setup();

        setBody (aString);

        httpResponse = tryToSend (this.httpRequest);

        return httpResponse.getBody();

    }

    private HttpResponse tryToSend (HttpRequest request) {

        for (Integer i = 0 ; i < 3; i++) {

            try {

                system.debug('>>>>>> this.httpRequest: ' + this.httpRequest);
                this.httpResponse = http.send(this.httpRequest);
                break;
            }
                catch (CalloutException e) {

                System.debug('  --------- Error [ retry ' + i + ' ] - ' + e.getMessage());

                if (i == 2) {
                    throw e;
                }

        }
    }

        postSend();

        handleResponseStatus(this.httpResponse);

        return this.httpResponse;
    }

    /**
     * Use this method to collect httpResponse value
     */
    virtual
    global void postSend() {
        System.debug('  --------- RESPONSE CODE : ' + httpResponse.getStatusCode());
        System.debug('  --------- RESPONSE Status : ' + httpResponse.getStatus());
        System.debug('  --------- RESPONSE BODY : ' + httpResponse.getBody());
    }

    virtual
    global void setBody (Object obj) {

        this.httpRequest.setBody (JSON.serialize(obj));
    }

    virtual
    global void setBody (String value) {

        this.httpRequest.setBody (value);
    }

    /*
    Valid Values = json / url
     */
    public void setContentType(String value){
        if(value.equalsIgnoreCase('url')){
         this.httpRequest.setHeader('Content-Type',URL_CONTENT_TYPE);
            return;
        }
        if(value.equalsIgnoreCase('son')) {
            this.httpRequest.setHeader('Content-Type', JSON_CONTENT_TYPE);
            return;
        }
        throw new EventObjectException('setContentValue set with invalid value :'+value);
    }

    public void setUriParameters( Map<String, String> uriParameters ) {
        if (uriParameters.size() >0) {
            uriString = '?';
        }

            for (String paramName : uriParameters.keySet()) {

                if (uriParameters.get(paramName) == null) {
                    continue;
                }

                uriString = uriString + paramName + '=' + uriParameters.get(paramName) + '&';
            }

        uriString.removeEnd('&');

    }

    virtual
    global void handleResponseStatus( HttpResponse response ) {

        if (response.getStatusCode() == 200) {
            return;
        }

        handleIntegrationErrorResponse(response);

    }

    virtual
    global void handleIntegrationErrorResponse ( HttpResponse response  ) {

        throw new IntegrationException (response);

    }

}
