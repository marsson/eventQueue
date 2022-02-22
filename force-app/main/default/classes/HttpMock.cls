/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
*/
@isTest
global class HttpMock implements HttpCalloutMock {

    String reponse;
    Boolean isSucess;

    global HttpMock (String reponse, Boolean success) {
        this.reponse = reponse;
        this.isSucess = success;
    }

    global HTTPResponse respond(HTTPRequest request) {
        return (this.isSucess ? buildSuccessResponse(reponse) : buildFailedResponse(reponse));
    }

    global HTTPResponse buildSuccessResponse  (String reponse) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody( reponse );
        res.setStatusCode(200);
        return res;
    }

    global HTTPResponse buildFailedResponse  (String reponse) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody( reponse );
        res.setStatusCode(400);
        return res;
    }

}