/**
 * @description Generic `HttpCalloutMock` for unit-testing outbound
 * commands. Returns either an HTTP 200 success response or an
 * HTTP 400 failure response with the supplied body.
 *
 * Usage:
 * <pre>
 * Test.setMock(HttpCalloutMock.class, new HttpMock('{"ok":true}', true));
 * </pre>
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@isTest
global class HttpMock implements HttpCalloutMock {

    String reponse;
    Boolean isSucess;

    /**
     * @description Configure the mock with a response body and a
     * success flag.
     * @param reponse Response body to return.
     * @param success true → HTTP 200; false → HTTP 400.
     */
    global HttpMock (String reponse, Boolean success) {
        this.reponse = reponse;
        this.isSucess = success;
    }

    /**
     * @description Standard `HttpCalloutMock` entry point.
     * @param request The outgoing request (ignored — mock is
     *                stateless).
     * @return The configured success or failure response.
     */
    global HTTPResponse respond(HTTPRequest request) {
        return (this.isSucess ? buildSuccessResponse(reponse) : buildFailedResponse(reponse));
    }

    /**
     * @description Build a 200 OK response.
     * @param reponse Body to return.
     * @return The constructed HTTP response.
     */
    global HTTPResponse buildSuccessResponse  (String reponse) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody( reponse );
        res.setStatusCode(200);
        return res;
    }

    /**
     * @description Build a 400 Bad Request response.
     * @param reponse Body to return.
     * @return The constructed HTTP response.
     */
    global HTTPResponse buildFailedResponse  (String reponse) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody( reponse );
        res.setStatusCode(400);
        return res;
    }

}
