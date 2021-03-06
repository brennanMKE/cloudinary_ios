//
//  UploaderTests.m
//  Cloudinary
//
//  Created by Tal Lev-Ami on 27/10/12.
//  Copyright (c) 2012 Cloudinary Ltd. All rights reserved.
//

#import "UploaderTests.h"

@interface UploaderTests () <CLUploaderDelegate> {
    NSString* error;
    NSDictionary* result;
}
@end

@implementation UploaderTests

#define VerifyAPISecret() { \
  if ([[[cloudinary config] valueForKey:@"api_secret"] length] == 0) {\
    NSLog(@"Must setup api_secret to run this test."); \
    return; \
  }}

- (void)setUp
{
    [super setUp];
    cloudinary = [[CLCloudinary alloc] init];
    error = nil;
    result = nil;
}

- (void)tearDown
{
    [super tearDown];
}

- (NSString*) logo
{
    return [[NSBundle bundleWithIdentifier:@"com.cloudinary.CloudinaryTests"] pathForResource:@"logo" ofType:@"png"];
}

- (void)waitForCompletion
{
    
    while (error == nil && result == nil)
    {
        NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:timeoutDate];
    }
    if (error != nil) {
        STFail(error);
    }
}

- (void)uploaderSuccess:(NSDictionary*)res context:(id)context
{
    result = res;
}

- (void)uploaderError:(NSString*)err code:(NSInteger) code context:(id)context
{
    error = err;
}

- (void) uploaderProgress:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite context:(id)context
{
    NSLog(@"%d/%d (+%d)", totalBytesWritten, totalBytesExpectedToWrite, bytesWritten);
}

- (void)testUpload
{
    VerifyAPISecret();
    CLUploader* uploader = [[CLUploader alloc] init:cloudinary delegate:self];
    [uploader upload:[self logo] options:[NSDictionary dictionary]];
    [self waitForCompletion];
    STAssertEqualObjects([result valueForKey:@"width"], [NSNumber numberWithInt:241], nil);
    STAssertEqualObjects([result valueForKey:@"height"], [NSNumber numberWithInt:51], nil);

    NSDictionary* toSign = [NSDictionary dictionaryWithObjectsAndKeys:
                            [result valueForKey:@"public_id"], @"public_id",
                            [result valueForKey:@"version"], @"version",
                            nil];
    NSString* expectedSignature = [cloudinary apiSignRequest:toSign secret:[cloudinary.config valueForKey:@"api_secret"]];
    STAssertEqualObjects([result valueForKey:@"signature"], expectedSignature, nil);
}

- (void)testUploadWithBlock
{
    VerifyAPISecret();
    CLUploader* uploader = [[CLUploader alloc] init:cloudinary delegate:nil];
    [uploader upload:[self logo] options:[NSDictionary dictionary] withCompletion:^(NSDictionary *success, NSString *errorResult, NSInteger code, id context) {
        result = success;
        error = errorResult;
    } andProgress:nil];
    [self waitForCompletion];
    STAssertEqualObjects([result valueForKey:@"width"], [NSNumber numberWithInt:241], nil);
    STAssertEqualObjects([result valueForKey:@"height"], [NSNumber numberWithInt:51], nil);
}

- (void)testUploadExternalSignature
{
    VerifyAPISecret();
    CLCloudinary* emptyCloudinary = [[CLCloudinary alloc] initWithUrl:@"cloudinary://a"];
    CLUploader* uploader = [[CLUploader alloc] init:emptyCloudinary delegate:self];
    NSDate *today = [NSDate date];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:(int) [today timeIntervalSince1970]] forKey:@"timestamp"];
    NSString* signature = [cloudinary apiSignRequest:params secret:[cloudinary.config valueForKey:@"api_secret"]];
    [params setValue:signature forKey:@"signature"];
    [params setValue:[cloudinary.config valueForKey:@"api_key"] forKey:@"api_key"];
    [params setValue:[cloudinary.config valueForKey:@"cloud_name"] forKey:@"cloud_name"];
    [uploader upload:[self logo] options:params];
    [self waitForCompletion];
}

- (void)testExplicit
{
    VerifyAPISecret();
    CLUploader* uploader = [[CLUploader alloc] init:cloudinary delegate:self];
    CLTransformation* transformation = [CLTransformation transformation];
    [transformation setCrop:@"scale"];
    [transformation setWidthWithFloat:2.0];
    [uploader explicit:@"cloudinary" options:[NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSArray arrayWithObject:transformation], @"eager",
                                              @"twitter_name", @"type"
                                              , nil]];
    [self waitForCompletion];
    NSString* url = [cloudinary url:@"cloudinary" options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           @"png", @"format",
                                                           [result valueForKey:@"version"], @"version",
                                                           @"twitter_name", @"type",
                                                           transformation, @"transformation",
                                                           nil]];
    NSArray* derivedList = [result valueForKey:@"eager"];
    NSDictionary* derived = [derivedList objectAtIndex:0];
    
    STAssertEqualObjects([derived valueForKey:@"url"], url, nil);
}

- (void) testEager
{
    VerifyAPISecret();
    CLUploader* uploader = [[CLUploader alloc] init:cloudinary delegate:self];
    CLTransformation* transformation = [CLTransformation transformation];
    [transformation setCrop:@"scale"];
    [transformation setWidthWithFloat:2.0];
    [uploader upload:[self logo] options:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSArray arrayWithObject:transformation], @"eager",
                                               nil]];
    [self waitForCompletion];
    
}

- (void) testHeaders
{
    VerifyAPISecret();
    CLUploader* uploader = [[CLUploader alloc] init:cloudinary delegate:self];
    [uploader upload:[self logo] options:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:@"Link: 1"]
                                                                           forKey:@"headers"]];
    [uploader upload:[self logo] options:[NSDictionary dictionaryWithObject:
                                                [NSDictionary dictionaryWithObject:@"1" forKey:@"Link"]
                                                                           forKey:@"headers"]];
    [self waitForCompletion];
}

- (void) testText
{
    VerifyAPISecret();
    CLUploader* uploader = [[CLUploader alloc] init:cloudinary delegate:self];
    [uploader text:@"hello world" options:[NSDictionary dictionary]];
    [self waitForCompletion];
    STAssertTrue([(NSNumber*)[result valueForKey:@"width"] integerValue] > 1, nil);
    STAssertTrue([(NSNumber*)[result valueForKey:@"height"] integerValue] > 1, nil);
}

@end
