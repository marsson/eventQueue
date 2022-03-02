#Execution Queue
The Execution queue is the implementation of a command design patters to orchestrate the execution of critical business proccesses within the Salesforce Platform.


## The Design Principles
The framework is based on an Open-source implementation, personalized to humm, in order to achieve the following design principles:

+ Performance by Asyncrossity
+ Preemptive customer support
+ Clear error handling
+ Override and Extension capabilities for mapped features.

## Local Vs. Global business processes.


The execution queue is supposed to be used for all the business processes that might need custom extension and traced reliability. 
Mapped usecases include:

+ Messaging (Sending emails or SMSs/ Emails).
+ Inbound events such as hooks for creating new records with operation result traceability.
+ outbound events such as direct connections to external systems in regions without a middleware.


## Benefits

+ Clear boundaries for business processes extension.
+ Configurable retry mechanism for events.
+ Stack trace and error message persisting in case of execution failure, allowing a preemptive support for customers.

## High-Level Design
The design of the application is based on a single custom object: the queue object. This object triggers custom code execution through a system apex trigger.
The creation or updation of an Event Queue in the “Queued” status triggers the execution of the logic configured for that given record.
There are 2 means of consumption or execution of the trigger objects. Through a Trigger on creation or updation of the object or through a scheduled job that runs every 5 minutes. The scheduled job is responsible for the retry mechanism of the solution.

From a functional perspective, once one business process is Identified or implemented, the customer can:

+ Use a default (virtual) implementation
+ Extend the virtual implementation to add localised functionality
+ Reimplement the business process completely to suit the localised needs.

##Configuring a Queue Event
Add a queue event name to the EventType Enumerator (EventType.cls). As a standard and for naming conventions, the queue names should be treated as CONSTANTS: Ex: MESSAGE_OUTBOUND_SERVICE, or SMS_OUTBOUND_SERVICE.
Create a custom metadata of the type Event Configuration, using the name of the EVENT TYPE as the label and name.
Fill Command Class Name with the name of the apex class that should be executed. The class must implement the ICommand protocol, or extend one of the abstract implementations.

##High volume execution using platform events
Platform events can be leveraged to get more performance out of the event queue execution. a specific platform event: 

## Installation:
Subscriber Package Version Id:  04t4x000000hwXZAAY
Package Installation URL: https://test.salesforce.com/packaging/installPackage.apexp?p0=04t4x000000hwXZAAY
As an alternative, you can use the "sfdx force:package:install" command:
sfdx force:package:install -p 04t4x000000hwXZAAY -w 30 -u queuePOC --installationkey VaiCurintia
