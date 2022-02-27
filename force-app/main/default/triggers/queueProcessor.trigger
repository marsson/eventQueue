trigger queueProcessor on queueEvent__e (after insert) {

    for (queueEvent__e event : Trigger.New) {

    }
}
