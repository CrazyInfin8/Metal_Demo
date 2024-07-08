#include "types.h"
#include "VertexData.h"
#include "mathUtilities.h"

#define uint32 MacOSUint32

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <simd/simd.h>

#undef uint32

bool pollEvents();

inline NSURL *bundleURL(NSString *path) {
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    if (path == nil) return bundleURL;
    return [bundleURL URLByAppendingPathComponent:path];
}

inline NSURL *resourcesURL(NSString *path) {
    NSURL *resourcesURL = bundleURL(@"Contents/Resources");
    if (path == nil) return resourcesURL;
    return [resourcesURL URLByAppendingPathComponent:path];
}

inline NSURL *assetsURL(NSString *path) {
    NSURL *assetsURL = bundleURL(@"Contents/Resources/assets");
    if (path == nil) return assetsURL;
    return [assetsURL URLByAppendingPathComponent:path];
}

#include <time.h>

float64 startTime = 0.0;

float64 currentTimeMillis() {
    if (startTime == 0.0) {
        startTime = (float64) clock() / CLOCKS_PER_SEC;
    }
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    float64 currentTime = (float64) ts.tv_sec * 1000.0 + (float64) ts.tv_nsec / 1000000.0;
    return currentTime - startTime;
}

@interface Texture : NSObject {
    id <MTLTexture> texture;
    int width;
    int height;
@private
    id <MTLDevice> device;
}

- (instancetype)loadAsset:(NSString *)path device:(id <MTLDevice>)device;

- (id <MTLTexture>)getTexture;
@end

@implementation Texture
- (instancetype)loadAsset:(NSString *)path device:(id <MTLDevice>)_device {
    [super init];
    device = _device;
    NSError *error;
    NSBitmapImageRep *image = (NSBitmapImageRep *) [NSBitmapImageRep imageRepWithContentsOfURL:assetsURL(path)];
    if (image == nil) {
        NSLog(@"Failed to load image: %@", path);
        [NSApp terminate:nil];
        exit(-1);
    }

    width = (int) image.size.width;
    height = (int) image.size.height;

    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDescriptor.width = (NSUInteger) width;
    textureDescriptor.height = (NSUInteger) height;

    texture = [device newTextureWithDescriptor:textureDescriptor];

    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    NSUInteger bytesPerRow = width * 4;

    [texture replaceRegion:region
               mipmapLevel:0
                 withBytes:[image bitmapData]
               bytesPerRow:width * 4];

    NSLog(@"Texture image size: %f, %f", image.size.width, image.size.height);

    [textureDescriptor release];
    [image release];
    return self;
}

- (oneway void)release {
    [texture release];
    [super release];
}

- (id <MTLTexture>)getTexture {
    return texture;
}
@end

@interface GameWindow : NSWindow {
    CAMetalLayer *layer;
    id <MTLDevice> device;
    id <CAMetalDrawable> drawable;
    id <MTLLibrary> shaderLibrary;
    id <MTLCommandQueue> commandQueue;
    id <MTLCommandBuffer> commandBuffer;
    id <MTLRenderPipelineState> renderPipeline;
    id <MTLBuffer> cubeVertexBuffer;
    id <MTLBuffer> transformationBuffer;
    id <MTLDepthStencilState> depthStencilState;
    MTLRenderPassDescriptor *renderPassDescriptor;
    id <MTLTexture> msaaTargetTexture;
    id <MTLTexture> depthTexture;
    Texture *grassTexture;
    int sampleCount;
}

- (instancetype)init;

- (void)run;

- (instancetype)createWindow;

- (void)closeWindow;

- (bool)pollEvents;

- (void)initGraphics;

- (void)closeGraphics;

- (void)createCube;

- (void)createBuffers;

- (void)createLibrary;

- (void)createCommandQueue;

- (void)createRenderPipeline;

- (void)createDepthAndMSAATextures;

- (void)createRenderPassDescriptor;

- (void)updateRenderPassDescriptor;

- (void)encodeRenderCommand:(id <MTLRenderCommandEncoder>)renderCommandEncoder;

- (void)sendRenderCommand;

- (void)draw;

- (NSSize)frameBufferSizeCallback:(NSSize)size;
@end

@interface GameWindowDelegate : NSObject <NSWindowDelegate> {
    GameWindow *window;
}
@end

@implementation GameWindowDelegate

- (instancetype)initWithWindow:(GameWindow *)_window {
    self = [super init];
    window = _window;
    return self;

}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
    return [window frameBufferSizeCallback:frameSize];
}
@end

@implementation GameWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- init {
    [self createWindow];
    [self initGraphics];

    [self createCube];
    [self createBuffers];
    [self createLibrary];
    [self createCommandQueue];
    [self createRenderPipeline];
    [self createDepthAndMSAATextures];
    [self createRenderPassDescriptor];
    return self;
}

- (void)run {
    while ([self pollEvents]) {
        @autoreleasepool {
            drawable = [layer nextDrawable];
            [self draw];
        }
    }
}

- (void)draw {
    [self sendRenderCommand];
}

- (instancetype)createWindow {

    self = [super initWithContentRect:NSMakeRect(
                    0, 0, 800, 600)
                            styleMask:NSWindowStyleMaskTitled |
                                      NSWindowStyleMaskClosable |
                                      NSWindowStyleMaskResizable
                              backing:NSBackingStoreBuffered
                                defer:NO];
    [self setTitle:@"Metal Demo"];
    [self makeKeyAndOrderFront:nil];
    [self center];
    [self setDelegate:[[GameWindowDelegate alloc] initWithWindow:self]];
    CGFloat scaleFactor = [self backingScaleFactor];
    if (scaleFactor > 1.0) {
        NSLog(@"Running in HiDPI mode");
    } else {
        NSLog(@"Running in standard resolution mode");
    }
    return self;
}

- (void)closeWindow {
    [self close];
    [self release];
}

- (bool)pollEvents {
    NSEvent *event;
    while (true) {
        event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                   untilDate:nil
                                      inMode:NSDefaultRunLoopMode
                                     dequeue:YES];
        if (event == nil) break;
        [NSApp sendEvent:event];
    }
    return true;
}

- (void)initGraphics {
    sampleCount = 4;
    device = MTLCreateSystemDefaultDevice();
    layer = [CAMetalLayer layer];
    layer.device = device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.drawableSize = self.contentView.frame.size;
    NSLog(@"layer drawable size: %f, %f", layer.drawableSize.width, layer.drawableSize.height);
    self.contentView.layer = layer;
    self.contentView.wantsLayer = YES;
    [self createRenderPassDescriptor];

    drawable = [layer nextDrawable];
}

- (void)closeGraphics {
    [transformationBuffer release];
    [msaaTargetTexture release];
    [depthTexture release];
    [device release];
    [grassTexture release];
}

- (void)createCube {
    const VertexData cubeVertices[] = {
            // Front face
            {{-0.5f, -0.5f, 0.5f,  1.0f}, {0.0f, 0.0f}},
            {{0.5f,  -0.5f, 0.5f,  1.0f}, {1.0f, 0.0f}},
            {{0.5f,  0.5f,  0.5f,  1.0f}, {1.0f, 1.0f}},
            {{0.5f,  0.5f,  0.5f,  1.0f}, {1.0f, 1.0f}},
            {{-0.5f, 0.5f,  0.5f,  1.0f}, {0.0f, 1.0f}},
            {{-0.5f, -0.5f, 0.5f,  1.0f}, {0.0f, 0.0f}},

            // Back face
            {{0.5f,  -0.5f, -0.5f, 1.0f}, {0.0f, 0.0f}},
            {{-0.5f, -0.5f, -0.5f, 1.0f}, {1.0f, 0.0f}},
            {{-0.5f, 0.5f,  -0.5f, 1.0f}, {1.0f, 1.0f}},
            {{-0.5f, 0.5f,  -0.5f, 1.0f}, {1.0f, 1.0f}},
            {{0.5f,  0.5f,  -0.5f, 1.0f}, {0.0f, 1.0f}},
            {{0.5f,  -0.5f, -0.5f, 1.0f}, {0.0f, 0.0f}},

            // Top face
            {{-0.5f, 0.5f,  0.5f,  1.0f}, {0.0f, 0.0f}},
            {{0.5f,  0.5f,  0.5f,  1.0f}, {1.0f, 0.0f}},
            {{0.5f,  0.5f,  -0.5f, 1.0f}, {1.0f, 1.0f}},
            {{0.5f,  0.5f,  -0.5f, 1.0f}, {1.0f, 1.0f}},
            {{-0.5f, 0.5f,  -0.5f, 1.0f}, {0.0f, 1.0f}},
            {{-0.5f, 0.5f,  0.5f,  1.0f}, {0.0f, 0.0f}},

            // Bottom face
            {{-0.5f, -0.5f, -0.5f, 1.0f}, {0.0f, 0.0f}},
            {{0.5f,  -0.5f, -0.5f, 1.0f}, {1.0f, 0.0f}},
            {{0.5f,  -0.5f, 0.5f,  1.0f}, {1.0f, 1.0f}},
            {{0.5f,  -0.5f, 0.5f,  1.0f}, {1.0f, 1.0f}},
            {{-0.5f, -0.5f, 0.5f,  1.0f}, {0.0f, 1.0f}},
            {{-0.5f, -0.5f, -0.5f, 1.0f}, {0.0f, 0.0f}},

            // Left face
            {{-0.5f, -0.5f, -0.5f, 1.0f}, {0.0f, 0.0f}},
            {{-0.5f, -0.5f, 0.5f,  1.0f}, {1.0f, 0.0f}},
            {{-0.5f, 0.5f,  0.5f,  1.0f}, {1.0f, 1.0f}},
            {{-0.5f, 0.5f,  0.5f,  1.0f}, {1.0f, 1.0f}},
            {{-0.5f, 0.5f,  -0.5f, 1.0f}, {0.0f, 1.0f}},
            {{-0.5f, -0.5f, -0.5f, 1.0f}, {0.0f, 0.0f}},

            // Right face
            {{0.5f,  -0.5f, 0.5f,  1.0f}, {0.0f, 0.0f}},
            {{0.5f,  -0.5f, -0.5f, 1.0f}, {1.0f, 0.0f}},
            {{0.5f,  0.5f,  -0.5f, 1.0f}, {1.0f, 1.0f}},
            {{0.5f,  0.5f,  -0.5f, 1.0f}, {1.0f, 1.0f}},
            {{0.5f,  0.5f,  0.5f,  1.0f}, {0.0f, 1.0f}},
            {{0.5f,  -0.5f, 0.5f,  1.0f}, {0.0f, 0.0f}},
    };

    cubeVertexBuffer = [device newBufferWithBytes:cubeVertices
                                           length:sizeof(cubeVertices)
                                          options:MTLResourceStorageModeShared];

    cubeVertexBuffer = [device newBufferWithBytes:cubeVertices
                                           length:sizeof(cubeVertices)
                                          options:MTLResourceStorageModeShared];

    transformationBuffer = [device newBufferWithLength:sizeof(Transformation)
                                               options:MTLResourceStorageModeShared];

    grassTexture = [[Texture alloc] loadAsset:@"mc_grass.jpeg" device:device];
}

- (void)createBuffers {
    transformationBuffer = [device newBufferWithLength:sizeof(Transformation)
                                               options:MTLResourceStorageModeShared];
}

- (void)createLibrary {
    NSError *error;
    shaderLibrary = [device newLibraryWithURL:resourcesURL(@"MetalShaderLibrary.metallib")
                                        error:&error];
    if (error != nil) {
        NSLog(@"Failed to create shader library");
        [NSApp terminate:nil];
        exit(-1);
    }
}

- (void)createCommandQueue {
    commandQueue = [device newCommandQueue];
}

- (void)createRenderPipeline {
    id <MTLFunction> vertexFunction = [shaderLibrary newFunctionWithName:@"vertexShader"];
    id <MTLFunction> fragmentFunction = [shaderLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.label = @"Triangle Rendering Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    assert(pipelineDescriptor);
    pipelineDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat;
    pipelineDescriptor.rasterSampleCount = sampleCount;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

    NSError *error = nil;
    renderPipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];

    if (renderPipeline == nil) {
        NSLog(@"Failed to create render pipeline state: %@", error);
        [NSApp terminate:nil];
        exit(-1);
    }

    MTLDepthStencilDescriptor *depthStencilDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
    depthStencilDescriptor.depthWriteEnabled = YES;
    depthStencilState = [device newDepthStencilStateWithDescriptor:depthStencilDescriptor];

    [pipelineDescriptor release];
    [vertexFunction release];
    [fragmentFunction release];
}

- (void)sendRenderCommand {
    commandBuffer = [commandQueue commandBuffer];

    [self updateRenderPassDescriptor];
    id <MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [self encodeRenderCommand:renderCommandEncoder];
    [renderCommandEncoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)createDepthAndMSAATextures {
    MTLTextureDescriptor *msaaTextureDescriptor = [[MTLTextureDescriptor alloc] init];
    msaaTextureDescriptor.textureType = MTLTextureType2DMultisample;
    msaaTextureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    msaaTextureDescriptor.width = (NSUInteger) layer.drawableSize.width;
    msaaTextureDescriptor.height = (NSUInteger) layer.drawableSize.height;
    msaaTextureDescriptor.sampleCount = sampleCount;
    msaaTextureDescriptor.usage = MTLTextureUsageRenderTarget;

    msaaTargetTexture = [device newTextureWithDescriptor:msaaTextureDescriptor];

    MTLTextureDescriptor *depthTextureDescriptor = [[MTLTextureDescriptor alloc] init];
    depthTextureDescriptor.textureType = MTLTextureType2DMultisample;
    depthTextureDescriptor.pixelFormat = MTLPixelFormatDepth32Float;
    depthTextureDescriptor.width = (NSUInteger) layer.drawableSize.width;
    depthTextureDescriptor.height = (NSUInteger) layer.drawableSize.height;
    depthTextureDescriptor.usage = MTLTextureUsageRenderTarget;
    depthTextureDescriptor.sampleCount = sampleCount;

    depthTexture = [device newTextureWithDescriptor:depthTextureDescriptor];

    [msaaTextureDescriptor release];
    [depthTextureDescriptor release];
}

- (void)createRenderPassDescriptor {
    renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    MTLRenderPassColorAttachmentDescriptor *colorAttachmentDescriptor = renderPassDescriptor.colorAttachments[0];
    colorAttachmentDescriptor.texture = msaaTargetTexture;
    [colorAttachmentDescriptor setResolveTexture:[drawable texture]];
    colorAttachmentDescriptor.loadAction = MTLLoadActionClear;
    colorAttachmentDescriptor.clearColor = MTLClearColorMake(41.0f / 255.0f, 42.0f / 255.0f, 48.0f / 255.0f, 1.0);
    colorAttachmentDescriptor.storeAction = MTLStoreActionMultisampleResolve;

    MTLRenderPassDepthAttachmentDescriptor *depthAttachmentDescriptor = renderPassDescriptor.depthAttachment;
    depthAttachmentDescriptor.texture = depthTexture;
    depthAttachmentDescriptor.loadAction = MTLLoadActionClear;
    depthAttachmentDescriptor.clearDepth = 1.0;
    depthAttachmentDescriptor.storeAction = MTLStoreActionDontCare;
}

- (void)updateRenderPassDescriptor {
    [renderPassDescriptor.colorAttachments[0] setTexture:msaaTargetTexture];
    [renderPassDescriptor.colorAttachments[0] setResolveTexture:[drawable texture]];
    [renderPassDescriptor.depthAttachment setTexture:depthTexture];
}

- (void)encodeRenderCommand:(id <MTLRenderCommandEncoder>)renderCommandEncoder {
    matrix_float4x4 translationMatrix = translationMatrix4x4(0.0f, 0.0f, -1.0f);

    float64 currentTime = currentTimeMillis();
    float angle = (float) fmod(currentTime * TO_RAD / 50, 360);
    matrix_float4x4 rotationMatrix = rotationMatrix4x4(angle, 0.0f, 1.0f, 0.0f);

    matrix_float4x4 modelMatrix = matrix_multiply(translationMatrix, rotationMatrix);

    simd_float3 R = {1.0f, 0.0f, 0.0f};
    simd_float3 U = {0.0f, 1.0f, 0.0f};
    simd_float3 F = {0.0f, 0.0f, -1.0f};
    simd_float3 P = {0.0f, 0.0f, 1.0f};

    simd_float4x4 viewMatrix = setMatrix4x4(
            R.x, R.y, R.z, simd_dot(-R, P),
            U.x, U.y, U.z, simd_dot(-U, P),
            -F.x, -F.y, -F.z, simd_dot(F, P),
            0.0f, 0.0f, 0.0f, 1.0f
    );

    float aspectRatio = (float) (layer.frame.size.width / layer.frame.size.height);
    float fov = 90 * TO_RAD;
    float nearZ = 0.1f;
    float farZ = 100.0f;

    simd_float4x4 perspectiveMatrix = matrixPerspectiveRightHand(fov, aspectRatio, nearZ, farZ);

    Transformation transformation = {
            .modelMatrix = modelMatrix,
            .viewMatrix = viewMatrix,
            .perspectiveMatrix = perspectiveMatrix
    };

    memcpy([transformationBuffer contents], &transformation, sizeof(Transformation));


    [renderCommandEncoder setRenderPipelineState:renderPipeline];
    [renderCommandEncoder setDepthStencilState:depthStencilState];
    [renderCommandEncoder setVertexBuffer:cubeVertexBuffer offset:0 atIndex:0];
    [renderCommandEncoder setVertexBuffer:transformationBuffer offset:0 atIndex:1];
    [renderCommandEncoder setFragmentTexture:[grassTexture getTexture] atIndex:0];
    [renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];
}

- (NSSize)frameBufferSizeCallback:(NSSize)size {
    NSLog(@"layer drawable size: %f, %f", layer.drawableSize.width, layer.drawableSize.height);
    layer.drawableSize = size;

    if (msaaTargetTexture != nil) {
        [msaaTargetTexture release];
        msaaTargetTexture = nil;
    }
    if (depthTexture != nil) {
        [depthTexture release];
        depthTexture = nil;
    }
    [self createDepthAndMSAATextures];
    drawable = [layer nextDrawable];
    @try {
        [self updateRenderPassDescriptor];
    } @catch (NSException *exception) {
        NSLog(@"Exception on line 533: %@", exception);
        @throw exception;
    }

    NSLog(@"###");
    return size;
}
@end

void closeWindow(GameWindow *window) { [window closeWindow]; }

bool pollEvents() {
    NSEvent *event;
    while (true) {
        event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                   untilDate:nil
                                      inMode:NSDefaultRunLoopMode
                                     dequeue:YES];
        if (event == nil) break;
        [NSApp sendEvent:event];
    }
    return true;
}

@interface AppDelegate : NSObject <NSApplicationDelegate> {
}
@end

@implementation AppDelegate
@end

void initApp() {
    NSApp = [NSApplication sharedApplication];
    [NSApp setDelegate:[[AppDelegate alloc] init]];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp finishLaunching];
}

void stopApp() {
    [NSApp terminate:nil];
}

int main() {
    initApp();
    GameWindow *window = [[GameWindow alloc] init];
    while (pollEvents()) {
        [window run];
    }
    closeWindow(window);
    stopApp();
    return 0;
}
