//
//  ViewController.m
//  Example
//
//  Created by Ronald Garay on 8/23/12.
//  Copyright (c) 2012 Ronald Garay. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () {
    EAGLContext *_context;
    GLuint _program;
    
    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_preview;
}

- (void)setupAVCapture;
- (void)setupGL;
- (void)setupBuffers;

- (void)teardownAVCapture;
- (void)teardownGL;
- (void)cleanUpTextures;

- (BOOL)compileShader:(GLuint *)shader withType:(GLenum)type andFile:(NSString *)file;
- (BOOL)loadShaders;
- (BOOL)linkProgram:(GLuint)prog;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
}

- (void)setupAVCapture
{
    _session = [[AVCaptureSession alloc] init];
    [_session beginConfiguration];
    
    [_session setSessionPreset:AVCaptureSessionPresetMedium];
    
    AVCaptureDevice *videoDevice;
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            videoDevice = device;
            break;
        }
    }
    
    if (!videoDevice) {
        assert(0);
    }
    
    NSError *error;
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    
    if (error) {
        assert(0);
    }
    
    [_session addInput:input];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    
    [output setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    [_session addOutput:output];
    [_session commitConfiguration];
    
    UIView *previewView = [[UIView alloc] initWithFrame:CGRectMake(20, 20, 200, 200)];
    
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    
    previewLayer.frame = CGRectMake(0, 0, 200, 200);
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    [previewView.layer addSublayer:previewLayer];
    [self.view addSubview:previewView];
}

- (void)setupGL
{
    
}

- (void)setupBuffers
{
    
}

- (void)teardownAVCapture
{
    
}

- (void)teardownGL
{
    
}

- (void)cleanUpTextures
{
    
}

- (BOOL)compileShader:(GLuint *)shader withType:(GLenum)type andFile:(NSString *)file
{
    return YES;
}

- (BOOL)loadShaders
{
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    return YES;
}

@end
