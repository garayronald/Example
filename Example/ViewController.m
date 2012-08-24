//
//  ViewController.m
//  Example
//
//  Created by Ronald Garay on 8/23/12.
//  Copyright (c) 2012 Ronald Garay. All rights reserved.
//

#import "ViewController.h"

//Uniforms for openGL
enum
{
    UNIFORM_Y,
    UNIFORM_U,
    UNIFORM_V,
    NUM_UNIFORMS
};

GLint uniforms[NUM_UNIFORMS];

//Attributes for openGL
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

@interface ViewController () {
    EAGLContext *_context;
    GLuint _program;
    
    GLuint yTexture, uTexture, vTexture;
    
    size_t planeSizes[2];
    size_t planeBPRs[2];
    size_t planeWidths[2];
    size_t planeHeights[2];
    
    uint8_t *yChannel, *cBChannel, *cRChannel;
    
    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_preview;
}

- (void)setupAVCapture;
- (void)setupGL;
- (void)setupTextures;

- (void)teardownAVCapture;
- (void)teardownGL;
- (void)cleanUpTextures;

- (BOOL)compileShader:(GLuint *)shader withType:(GLenum)type andFile:(NSString *)file;
- (BOOL)loadShaders;
- (BOOL)linkProgram:(GLuint)prog;

- (void)render;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = _context;
    self.preferredFramesPerSecond = 60;
    
    [self setupGL];
    
    [self setupAVCapture];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [self teardownAVCapture];
    [self teardownGL];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (interfaceOrientation == UIInterfaceOrientationPortrait) {
        return YES;
    } else {
        return NO;
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef pixelBuff = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuff, 0);
    
    planeWidths[0] = CVPixelBufferGetWidthOfPlane(pixelBuff, 0);
    planeWidths[1] = CVPixelBufferGetWidthOfPlane(pixelBuff, 1);
    
    planeHeights[0] = CVPixelBufferGetHeightOfPlane(pixelBuff, 0);
    planeHeights[1] = CVPixelBufferGetHeightOfPlane(pixelBuff, 1);
    
    planeBPRs[0] = CVPixelBufferGetBytesPerRowOfPlane(pixelBuff, 0);
    planeBPRs[1] = CVPixelBufferGetBytesPerRowOfPlane(pixelBuff, 1);
    
    planeSizes[0] = planeBPRs[0] * planeHeights[0];
    planeSizes[1] = planeBPRs[1] * planeHeights[1];
    
    yChannel = CVPixelBufferGetBaseAddressOfPlane(pixelBuff, 0);
    
    uint8_t *cbCrChannel = CVPixelBufferGetBaseAddressOfPlane(pixelBuff, 1);
    
    cBChannel = (uint8_t *)malloc(planeSizes[1]/2);
    cRChannel = (uint8_t *)malloc(planeSizes[1]/2);
    
    uint8_t *u = cBChannel;
    uint8_t *v = cRChannel;
    
    for(int i = 0; i < planeSizes[1]; i++) {
        if(i % 2 == 0) {
            *u = *cbCrChannel;
            u++;
        } else {
            *v = *cbCrChannel;
            v++;
        }
        cbCrChannel++;
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuff, 0);
    
    [self setupTextures];
    [self render];
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
    
    [_session startRunning];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:_context];
    
    [self loadShaders];
    
    glUseProgram(_program);
    
    /*** NEED TO SET UP UNIFORMS/TEXTURES OR ANYTHING OF THAT SORT ***/
}

- (void)setupTextures
{
    // Y Texture
    if (yTexture) glDeleteTextures(1, &yTexture);
    
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &yTexture);
    glBindTexture(GL_TEXTURE_2D, yTexture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // This is necessary for non-power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glEnable(GL_TEXTURE_2D);
    
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_LUMINANCE,
                 planeWidths[0],
                 planeHeights[0],
                 0,
                 GL_LUMINANCE,
                 GL_UNSIGNED_BYTE,
                 NULL);
    
    // U Texture
    if (uTexture) glDeleteTextures(1, &uTexture);
    
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &uTexture);
    glBindTexture(GL_TEXTURE_2D, uTexture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // This is necessary for non-power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glEnable(GL_TEXTURE_2D);
    
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_LUMINANCE,
                 planeWidths[1]/2,
                 planeHeights[1]/2,
                 0,
                 GL_LUMINANCE,
                 GL_UNSIGNED_BYTE,
                 NULL);
    
    // V Texture
    if (vTexture) glDeleteTextures(1, &vTexture);
    
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &vTexture);
    glBindTexture(GL_TEXTURE_2D, vTexture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // This is necessary for non-power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glEnable(GL_TEXTURE_2D);
    
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_LUMINANCE,
                 planeWidths[1]/2,
                 planeHeights[1]/2,
                 0,
                 GL_LUMINANCE,
                 GL_UNSIGNED_BYTE,
                 NULL);
}

- (void)teardownAVCapture
{
    [self cleanUpTextures];
    
}

- (void)teardownGL
{
    [EAGLContext setCurrentContext:_context];
    
    /*** DELETE ANY BUFFER ETC. ***/
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

- (void)cleanUpTextures
{
    
}

- (BOOL)compileShader:(GLuint *)shader withType:(GLenum)type andFile:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
/*
#if defined(DEBUG)
    GLint loglength;
    glGetShaderiv(*shader, loglength, &loglength);
    
    if(loglength > 0) {
        GLchar *log = (GLchar *)malloc(loglength);
        glGetShaderInfoLog(*shader, loglength, &loglength, log);
        NSLog(@"Shader compile log:\n%s",log);
        free(log);
    }
#endif
*/
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertPath, *fragPath;
    
    _program = glCreateProgram();
    
    vertPath = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    
    if (![self compileShader:&vertShader withType:GL_VERTEX_SHADER andFile:vertPath]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    fragPath = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    
    if (![self compileShader:&fragShader withType:GL_FRAGMENT_SHADER andFile:fragPath]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    glAttachShader(_program, vertShader);
    
    glAttachShader(_program, fragShader);
    
    /*** BIND ATTRIBUTES ***/
    
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    /*** GET UNIFORM/TEXTURE LOCATION ***/
    
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
/*
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
*/    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (void)render
{
    // Y data
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, yTexture);
    glUniform1i(uniforms[UNIFORM_Y], 1);
    
    glTexSubImage2D(
                    GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    planeWidths[0],            // source width
                    planeHeights[0],            // source height
                    GL_LUMINANCE,
                    GL_UNSIGNED_BYTE,
                    yChannel);
    
    // U data
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, uTexture);
    glUniform1i(uniforms[UNIFORM_U], 2);
    
    glTexSubImage2D(
                    GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    planeWidths[1]/2,            // source width
                    planeHeights[1]/2,            // source height
                    GL_LUMINANCE,
                    GL_UNSIGNED_BYTE,
                    cBChannel);
    

    // V data
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, vTexture);
    glUniform1i(uniforms[UNIFORM_V], 3);
    
    glTexSubImage2D(
                    GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    planeWidths[1]/2,            // source width
                    planeHeights[1]/2,            // source height
                    GL_LUMINANCE,
                    GL_UNSIGNED_BYTE,
                    cRChannel);
}

@end
