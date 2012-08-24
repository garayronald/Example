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
    SAMPLE_Y,
    SAMPLE_U,
    SAMPLE_V,
    NUM_SAMPLES
};

//Attributes for openGL
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

static const float kVertices[8] = {
    -1.f, 1.f,
    -1.f, -1.f,
    1.f, 1.f,
    1.f, -1.f,
};

static const float kTextureCoords[8] = {
    0, 0,
    0, 1,
    1, 0,
    1, 1,
};

@interface ViewController () {
    EAGLContext *_context;
    GLuint _program;
    GLuint attributes[NUM_ATTRIBUTES];
    GLuint _textures[NUM_SAMPLES];
    GLint uniforms[NUM_SAMPLES];
    
    size_t planeSizes[2];
    size_t planeBPRs[2];
    size_t planeWidths[2];
    size_t planeHeights[2];
    
    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_preview;
}

- (void)setupAVCapture;
- (void)setupGL;
- (void)setupTextures;
- (void)teardownAVCapture;
- (void)teardownGL;
- (void)teardownTextures;
- (void)render;
- (BOOL)compileShader:(GLuint *)shader withType:(GLenum)type andFile:(NSString *)file;
- (BOOL)loadShaders;
- (BOOL)linkProgram:(GLuint)prog;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_context) {
        NSLog(@"Failed to create ES context");
    }
    
    //GLKView *view = (GLKView *)self.view;
    //view.context = _context;
    //self.preferredFramesPerSecond = 60;
    
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
    
    uint8_t *yChannel = CVPixelBufferGetBaseAddressOfPlane(pixelBuff, 0);
    
    uint8_t *cbCrChannel = CVPixelBufferGetBaseAddressOfPlane(pixelBuff, 1);
    
    uint8_t *cBChannel = (uint8_t *)malloc(planeSizes[1]/2);
    uint8_t *cRChannel = (uint8_t *)malloc(planeSizes[1]/2);
    
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
    
    [self renderWithDataY:yChannel dataU:cBChannel dataV:cRChannel];
    
    CVPixelBufferUnlockBaseAddress(pixelBuff, 0);
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

- (void)teardownAVCapture
{
    
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:_context];
    
    [self setupTextures];
    
    [self loadShaders];
    
    uniforms[SAMPLE_Y] = glGetUniformLocation(_program, "sampler_y");
    glUniform1i(uniforms[SAMPLE_Y], 0);
    
    uniforms[SAMPLE_U] = glGetUniformLocation(_program, "sampler_u");
    glUniform1i(uniforms[SAMPLE_U], 0);
    
    uniforms[SAMPLE_V] = glGetUniformLocation(_program, "sampler_v");
    glUniform1i(uniforms[SAMPLE_V], 0);
    
    attributes[ATTRIB_VERTEX] = glGetAttribLocation(_program, "position");
    glEnableVertexAttribArray(attributes[ATTRIB_VERTEX]);
    glVertexAttribPointer(attributes[ATTRIB_VERTEX], 2, GL_FLOAT, GL_FALSE, 0, kVertices);
    
    attributes[ATTRIB_TEXCOORD] = glGetAttribLocation(_program, "texCoordIn");
    glEnableVertexAttribArray(attributes[ATTRIB_TEXCOORD]);
    glVertexAttribPointer(attributes[ATTRIB_TEXCOORD], 2, GL_FLOAT, GL_FALSE, 0,
                          kTextureCoords);
}

- (void)teardownGL
{
    [EAGLContext setCurrentContext:_context];
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

- (void)setupTextures
{
    //Create 3 textues
    glGenTextures(3, _textures);
    glActiveTexture(GL_TEXTURE0);
    
    // Y texture
    glBindTexture(GL_TEXTURE_2D, _textures[SAMPLE_Y]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glEnable(GL_TEXTURE_2D);
    
    // U texture
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _textures[SAMPLE_U]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glEnable(GL_TEXTURE_2D);
    
    // V texture
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, _textures[SAMPLE_V]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glEnable(GL_TEXTURE_2D);
}

- (void)teardownTextures
{

}

- (void)renderWithDataY:(uint8_t *)y_data dataU:(uint8_t *)u_data dataV:(uint8_t *)v_data
{
    // Y data
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _textures[SAMPLE_Y]);
    glUniform1i(_textures[SAMPLE_Y], 0);
    
    glTexSubImage2D(
                    GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    planeBPRs[0],            // source width
                    planeHeights[0],            // source height
                    GL_LUMINANCE,
                    GL_UNSIGNED_BYTE,
                    y_data);
    
    // U data
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, _textures[SAMPLE_U]);
    glUniform1i(_textures[SAMPLE_U], 1);
    
    glTexSubImage2D(
                    GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    planeBPRs[1]/2,            // source width
                    planeHeights[1]/2,            // source height
                    GL_LUMINANCE,
                    GL_UNSIGNED_BYTE,
                    u_data);
    
    // V data
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _textures[SAMPLE_V]);
    glUniform1i(_textures[SAMPLE_V], 2);
    
    glTexSubImage2D(
                    GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    planeBPRs[1]/2,            // source width
                    planeHeights[1]/2,            // source height
                    GL_LUMINANCE,
                    GL_UNSIGNED_BYTE,
                    v_data);
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
    NSString *vertShaderPath, *fragShaderPath;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPath = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    
    if (![self compileShader:&vertShader withType:GL_VERTEX_SHADER andFile:vertShaderPath]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Release vertex shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    
    // Create and compile fragment shader.
    fragShaderPath = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    
    if (![self compileShader:&fragShader withType:GL_FRAGMENT_SHADER andFile:fragShaderPath]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Release fragment shaders.
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
