/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <XCTest/XCTest.h>
#import "UAAction+Internal.h"
#import "UAAction+Operators.h"

@interface UAAction_OperatorTest : XCTestCase
@property (nonatomic, strong)UAActionArguments *emptyArgs;
@end


@implementation UAAction_OperatorTest

- (void)setUp {
    self.emptyArgs = [UAActionArguments argumentsWithValue:nil withSituation:nil];

    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}


/**
 * Tests the bind operator
 */

- (void)testBind {

    //we'll store our action results here for assertion
    __block UAActionResult *blockResult;

    //a completion handler that saves action results in the above variable
    UAActionCompletionHandler saveBlockResult = ^(UAActionResult *result) {
        blockResult = result;
    };

    //this action just finishes immediately with a result whose value is the string @"simpleResult"
    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        handler([UAActionResult resultWithValue:@"simpleResult"]);
    }];

    [action performWithArguments:nil withCompletionHandler:saveBlockResult];
    XCTAssertEqualObjects(blockResult.value, @"simpleResult", @"the result value should be 'simpleResult'");

    //a bind block defines a transformation between action blocks, and between predicates, and returns a new action
    UAActionBindBlock bindBlock = ^(UAActionBlock actionBlock, UAActionPredicate predicate){
        //the transformed action block calls the original action block, and produces a result value that concatenates
        //the string @"to the max" on the end of the original result
        UAActionBlock transformedActionBlock = ^(UAActionArguments *args, UAActionCompletionHandler handler) {
            actionBlock(args, ^(UAActionResult *result){
                NSString *concatenatedValue = [result.value stringByAppendingString:@" to the Max!!!!"];
                handler([UAActionResult resultWithValue:concatenatedValue]);
            });
        };

        //for simplicity in this example, the transformed predicate is just the same predicate
        UAActionPredicate transformedPredicate = ^(UAActionArguments *args) {
            return predicate(args);
        };

        //construct a new action, passing in the transformed action block and predicate
        UAAction *aggregate = [UAAction actionWithBlock:transformedActionBlock acceptingArguments:transformedPredicate];

        return aggregate;
    };

    //construct a new action by binding to the above bind block
    UAAction *actionToTheMax = [action bind:bindBlock];

    //now when we run the new action, we should see the concatenation in the results
    [actionToTheMax performWithArguments:nil withCompletionHandler:saveBlockResult];
    XCTAssertEqualObjects(blockResult.value, @"simpleResult to the Max!!!!", @"the result value should be 'simpleResult to the Max!!!!'");

    //the original result isn't hardcoded into the transformation, we can take anything to the max
    UAAction *hobo = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        handler([UAActionResult resultWithValue:@"hobo"]);
    }];

    UAAction *hoboToTheMax = [hobo bind:bindBlock];

    [hoboToTheMax performWithArguments:nil withCompletionHandler:saveBlockResult];
    XCTAssertEqualObjects(blockResult.value, @"hobo to the Max!!!!", @"the result value should be 'hobo to the Max!!!!'");
}

/**
 * Tests the lift operator
 */

- (void)testLift {

    //we'll store our action results here for assertion
    __block UAActionResult *blockResult;

    //a completion handler that saves action results in the above variable
    UAActionCompletionHandler saveBlockResult = ^(UAActionResult *result) {
        blockResult = result;
    };

    //this action just finishes immediately with a result whose value is the string @"simpleResult"
    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        handler([UAActionResult resultWithValue:@"simpleResult"]);
    }];

    [action performWithArguments:nil withCompletionHandler:saveBlockResult];
    XCTAssertEqualObjects(blockResult.value, @"simpleResult", @"the result value should be 'simpleResult'");

    //an action lift block defines a transformation between action blocks
    //note: since lift depends on bind, we don't actually have to explicitly create a new action here
    UAActionLiftBlock liftBlock = ^(UAActionBlock actionBlock) {
        //the transformed action block calls the original action block, and produces a result value that concatenates
        //the string @"to the max" on the end of the original result
        UAActionBlock transformedActionBlock = ^(UAActionArguments *args, UAActionCompletionHandler handler){
            actionBlock(args, ^(UAActionResult *result){
                NSString *concatenatedValue = [result.value stringByAppendingString:@" to the Max!!!!"];
                handler([UAActionResult resultWithValue:concatenatedValue]);
            });
        };
        return transformedActionBlock;
    };

    //lifting the actionLiftBlock produces a new action derived from the original one.
    //the simple lift operator here assumes you don't want to change the predicate block, so the
    //resulting action will inherit the receiver's argument validation logic
    UAAction *actionToTheMax = [action lift:liftBlock];

    [actionToTheMax performWithArguments:nil withCompletionHandler:saveBlockResult];
    XCTAssertEqualObjects(blockResult.value, @"simpleResult to the Max!!!!", @"the result value should be 'simpleResult to the Max!!!!'");
}

- (void)testLiftTransformingPredicate {

    //we'll store our action results here for assertion
    __block UAActionResult *blockResult;

    //a completion handler that saves action results in the above variable
    UAActionCompletionHandler saveBlockResult = ^(UAActionResult *result) {
        blockResult = result;
    };

    //this action just finishes immediately with a result whose value is the string @"simpleResult".
    //we're also adding some arbitrary argument validation.  this one will reject arguments whose
    //value is the string @"foo".
    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        handler([UAActionResult resultWithValue:@"simpleResult"]);
    } acceptingArguments:^(UAActionArguments *args){
        return (BOOL)![args.value isEqual:@"foo"];
    }];

    [action performWithArguments:nil withCompletionHandler:saveBlockResult];
    XCTAssertEqualObjects(blockResult.value, @"simpleResult", @"the result value should be 'simpleResult'");

    UAActionArguments *fooArgs = [UAActionArguments argumentsWithValue:@"foo" withSituation:nil];

    XCTAssertFalse([action acceptsArguments:fooArgs], @"action should not accept arguments with value 'foo'");

    //an action lift block defines a transformation between action blocks
    UAActionLiftBlock actionLiftBlock = ^(UAActionBlock actionBlock) {
        //the transformed action block calls the original action block, and produces a result value that concatenates
        //the string @"to the max" on the end of the original result
        UAActionBlock transformedActionBlock = ^(UAActionArguments *args, UAActionCompletionHandler handler){
            actionBlock(args, ^(UAActionResult *result){
                NSString *concatenatedValue = [result.value stringByAppendingString:@" to the Max!!!!"];
                handler([UAActionResult resultWithValue:concatenatedValue]);
            });
        };
        return transformedActionBlock;
    };

    //a predicate lift block defines a transformation between predicates.
    UAActionPredicateLiftBlock predicateLiftBlock = ^(UAActionPredicate predicate){
        //this one inherits the logic of the existing predicate, and adds logic that
        //rejects arguments whose value is the string @"bar".
        UAActionPredicate transformedPredicate = ^(UAActionArguments *args) {
            BOOL accepts = predicate(args);
            accepts = accepts && (![args.value isEqual:@"bar"]);
            return accepts;
        };

        return transformedPredicate;
    };

    //lifting the actionLiftBlock and predicateLiftBlock produces a new action derived from the original one.
    //both the original action and acceptsArguments logic have been preserved but extended.
    UAAction *actionToTheMax = [action lift:actionLiftBlock transformingPredicate:predicateLiftBlock];

    [actionToTheMax performWithArguments:nil withCompletionHandler:saveBlockResult];
    XCTAssertEqualObjects(blockResult.value, @"simpleResult to the Max!!!!", @"the result value should be 'simpleResult to the Max!!!!'");

    UAActionArguments *barArgs = [UAActionArguments argumentsWithValue:@"bar" withSituation:nil];

    XCTAssertFalse([actionToTheMax acceptsArguments:fooArgs], @"actionToTheMax should not accept arguments with value 'foo'");
    XCTAssertFalse([actionToTheMax acceptsArguments:barArgs], @"actionToTheMax should not accept arguments with value 'bar'");
}

/**
 * Tests the continueWith operator
 */
- (void)testContinueWith {
    __block BOOL didContinuationActionRun = NO;
    __block UAActionResult *result;
    __block UAActionArguments *continuationArguments;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        return completionHandler([UAActionResult resultWithValue:@"originalResult"]);
    }];

    UAAction *continuationAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        continuationArguments = args;
        didContinuationActionRun = YES;
        return completionHandler([UAActionResult resultWithValue:@"continuationResult"]);
    }];

    action = [action continueWith:continuationAction];
    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult){
        result = actionResult;
    }];

    XCTAssertTrue(didContinuationActionRun, @"The continuation action should be run if the original action does not return an error.");
    XCTAssertEqualObjects(continuationArguments.value, @"originalResult", @"The continuation action should be passed a new argument with the value of the previous result");
    XCTAssertEqualObjects(result.value, @"continuationResult", @"Running a continuation action should call completion handler with the result from the continuation action");
}

/**
 * Test that the continueWith does not call the continuationAction if the original
 * action returns an error result
 */
- (void)testContinueWithError {
    __block BOOL didContinuationActionRun = NO;
    __block UAActionResult *result;

    UAActionResult *errorResult = [UAActionResult error:[NSError errorWithDomain:@"some-domian" code:10 userInfo:nil]];


    // Set up action to return an error result
    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        return completionHandler(errorResult);
    }];

    UAAction *continuationAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        didContinuationActionRun = YES;
        completionHandler([UAActionResult none]);
    }];

    action = [action continueWith:continuationAction];
    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult){
        result = actionResult;
    }];

    XCTAssertFalse(didContinuationActionRun, @"The continuation action should not run if the original action returns an error.");
    XCTAssertEqual(result, errorResult, @"Completion handler should be called with the original result if the continuation action is not called.");
}

/**
 * Test continueWith when passing a nil continuation action
 */
- (void)testContinueWithNilAction {
    __block UAActionResult *result;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        return completionHandler([UAActionResult resultWithValue:@"originalResult"]);
    }];


    action = [action continueWith:nil];
    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult){
        result = actionResult;
    }];

    XCTAssertEqualObjects(result.value, @"originalResult", @"Continue with should ignore a nil continue with action and just return the original action's result");
}

/**
 * Test the filter operator behavior when a predicate returns YES
 */
- (void)testFilterYesPredicate {
    __block BOOL didPerform = NO;
    UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didPerform = YES;
        return completionHandler(expectedResult);
    }];

    action = [action filter:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(self.emptyArgs, args, @"Filter predicate block is not being passed the correct action arguments");
        return YES;
    }];

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(result, expectedResult, @"Filter result is unexpected");
    }];

    XCTAssertTrue(didPerform, @"When filter returns YES, it should perform the original action");

    // Run it again, this time the action should reject the arguments
    didPerform = NO;

    action.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return NO;
    };

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        XCTAssertNil(result.value, @"Run should return a empty result if the action cannot be run");
    }];

    XCTAssertFalse(didPerform, @"When filter returns YES, but the action still cannot run, it should not perform");
}

/**
 * Test the filter operator behavior when a predicate returns NO
 */
- (void)testFilterNoPredicate {
    __block UAActionResult *result;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTFail(@"When filter returns NO, it should not perform the original action");
        return completionHandler([UAActionResult none]);
    }];

    action = [action filter:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(self.emptyArgs, args, @"Filter predicate block is not being passed the correct action arguments");
        return NO;
    }];

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult) {
        result = actionResult;
    }];

    XCTAssertNotNil(result, @"Run should still return a result if the filter returns NO");
    XCTAssertNil(result.value, @"Run should return a empty result if the filter returns NO");
}

/**
 * Test the filter operator with a nil predicate block does not change the actions
 * run behavior
 */
- (void)testFilterNilPredicate {
    __block BOOL didPerform = NO;
    UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didPerform = YES;
        return completionHandler(expectedResult);
    }];

    action = [action filter:nil];

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(result, expectedResult, @"Filter result is unexpected");
    }];

    XCTAssertTrue(didPerform, @"Action should still perform if the predicate is nil");
}

/**
 * Test the map operator only changes the arguments passed into the original action
 */
- (void)testMap {
    UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];
    UAActionArguments *mappedArgs = [UAActionArguments argumentsWithValue:@"map-value"
                                                            withSituation:@"mapuation"];

    __block UAActionResult *result;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTAssertEqualObjects(mappedArgs, args, @"Action is not receiving mapped args");
        return completionHandler(expectedResult);
    }];

    action = [action map:^UAActionArguments *(UAActionArguments *originalArgs) {
        XCTAssertEqualObjects(self.emptyArgs, originalArgs, @"Mapped action is not receiving original arguments");
        return mappedArgs;
    }];

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult) {
        result = actionResult;
    }];

    XCTAssertEqualObjects(result, expectedResult, @"Mapped action operator produces unexpected results");
}

/**
 * Test the map operator nil block does not change the arguments passed to the
 * original action
 */
- (void)testMapNilBlock {
    UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];
    __block UAActionResult *result;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTAssertEqualObjects(self.emptyArgs, args, @"Action is not receiving correct args");
        return completionHandler(expectedResult);
    }];

    action = [action map:nil];

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult) {
        result = actionResult;
    }];

    XCTAssertEqualObjects(result, expectedResult, @"Mapped action operator with nil block produces unexpected results");
}

/*
 * Test preExecution operator performs a UAActionPreExecutionBlock before
 * the action is performed
 */
- (void)testPreExecution {
    __block BOOL didPerform = NO;
    __block BOOL preExecutePerformed = NO;
    UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didPerform = YES;

        XCTAssertTrue(preExecutePerformed, @"Pre execute block is not being called before perform");
        return completionHandler(expectedResult);
    }];

    action = [action preExecution:^(UAActionArguments *args) {
        preExecutePerformed = YES;

        XCTAssertFalse(didPerform, @"Pre execute block is not being called before perform");
        XCTAssertEqualObjects(self.emptyArgs, args, @"Pre execute block is being passed the correct action arguments");
    }];

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(result, expectedResult, @"preExecution result is unexpected");
    }];

    XCTAssertTrue(didPerform, @"Pre execution block is preventing the original action from running");
}

/*
 * Test preExecution operator with a nil block does not hinder the original action
 */
- (void)testPreExecutionNilBlock {
    __block BOOL didPerform = NO;
    UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didPerform = YES;
        return completionHandler(expectedResult);
    }];

    action = [action preExecution:nil];
    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(result, expectedResult, @"preExecution result is unexpected");
    }];

    XCTAssertTrue(didPerform, @"Nil pre execution block is preventing the original action from running");
}

/*
 * Test postExecution operator performs a UAActionPostExecutionBlock after
 * the action is performed but before the completion handler is called
 */
- (void)testPostExecution {
    __block BOOL didPerform = NO;
    __block BOOL postExecuteBlock = NO;
    UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didPerform = YES;

        XCTAssertFalse(postExecuteBlock, @"Post execute block is being called before perform");
        return completionHandler(expectedResult);
    }];

    action = [action postExecution:^(UAActionArguments *args, UAActionResult *result) {
        postExecuteBlock = YES;

        XCTAssertTrue(didPerform, @"Perform is not being called before post execution block");

        XCTAssertEqualObjects(self.emptyArgs, args, @"Post execute block is not being passed the correct action arguments");
        XCTAssertEqualObjects(expectedResult, result, @"Post execute block is not being passed the correct action result");
    }];

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        XCTAssertTrue(postExecuteBlock, @"Post execute block is not being called before the completion handler is called");
        XCTAssertEqualObjects(result, expectedResult, @"postExecution result is unexpected");
    }];

    XCTAssertTrue(didPerform, @"Post execution block is preventing the original action from running");
}

/*
 * Test postExecution operator with a nil block does not hinder the original action
 */
- (void)testPostExecutionNilBlock {
    __block BOOL didPerform = NO;
    UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didPerform = YES;
        return completionHandler(expectedResult);
    }];
    
    action = [action postExecution:nil];
    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(result, expectedResult, @"postExecution result is unexpected");
    }];
    
    XCTAssertTrue(didPerform, @"Nil post execution block is preventing the original action from running");
}

@end
