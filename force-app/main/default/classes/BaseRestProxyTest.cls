/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
*/
@isTest
private class BaseRestProxyTest {

    @isTest
    static void sendPostRequest() {

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');

        Test.setMock( HttpCalloutMock.class , new HttpMock ('{"response":"ok"}', true) );
        Test.startTest();


        RestProxy proxy = new RestProxy(event);

        String reponse = proxy.send ('request');

        proxy = new RestProxy();

        Test.stopTest();


    }

    @isTest
    static void sendGetRequest() {

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');

        Test.setMock( HttpCalloutMock.class , new HttpMock ('{"response":"ok"}', true) );
        Test.startTest();

        RestProxy proxy = new RestProxy(event);

        String reponse = proxy.get ( new Map<String, String> {'key' => 'value'});
        Test.stopTest();

    }


    @isTest
    static void sendPostRequestFail() {

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');

        Test.setMock( HttpCalloutMock.class , new HttpMock ('{"returnRS":[{"messageType":"E","messageNumber":"200","messageText":"Para o cliente não existe nenhum mestre de cliente","messageLog":"000000"},{"messageType":"E","messageNumber":"219","messageText":"O doc.vendas não será modificado","messageLog":"000000"}]}', false) );
        Test.startTest();


        RestProxy proxy = new RestProxy(event);

        try {
            String reponse = proxy.send ('request');
        } catch (Exception e) {}


        proxy = new RestProxy();

        Test.stopTest();


    }


}