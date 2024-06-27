#include "types.h"
#include "VertexData.h"

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

@interface Texture : NSObject {
    id <MTLTexture> texture;
    int width;
    int height;
    int channels;
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
    channels = 4;

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
    id <MTLBuffer> vertexBuffer;

    Texture *grassTexture;
}

- (instancetype)init;

- (void)run;

- (instancetype)createWindow;

- (void)closeWindow;

- (bool)pollEvents;

- (void)initGraphics;

- (void)createSquare;

- (void)createLibrary;

- (void)createCommandQueue;

- (void)createRenderPipeline;

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

    [self createSquare];
    [self createLibrary];
    [self createCommandQueue];
    [self createRenderPipeline];
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
    device = MTLCreateSystemDefaultDevice();
    layer = [CAMetalLayer layer];
    layer.device = device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.drawableSize = self.contentView.frame.size;
    NSLog(@"layer drawable size: %f, %f", layer.drawableSize.width, layer.drawableSize.height);
    self.contentView.layer = layer;
    self.contentView.wantsLayer = YES;
}

- (void)createSquare {
    const VertexData squareVertices[] = {
            {{-0.5f, -0.5f, 0.5f, 1.0f}, {0.0f, 0.0f}},
            {{-0.5f, 0.5f,  0.5f, 1.0f}, {0.0f, 1.0f}},
            {{0.5f,  0.5f,  0.5f, 1.0f}, {1.0f, 1.0f}},
            {{-0.5f, -0.5f, 0.5f, 1.0f}, {0.0f, 0.0f}},
            {{0.5f,  0.5f,  0.5f, 1.0f}, {1.0f, 1.0f}},
            {{0.5f,  -0.5f, 0.5f, 1.0f}, {1.0f, 0.0f}}
    };

    vertexBuffer = [device newBufferWithBytes:squareVertices
                                       length:sizeof(squareVertices)
                                      options:MTLResourceStorageModeShared];

    grassTexture = [[Texture alloc] loadAsset:@"mc_grass.jpeg" device:device];
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

    NSError *error = nil;
    renderPipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    [pipelineDescriptor release];
}

- (void)sendRenderCommand {
    commandBuffer = [commandQueue commandBuffer];

    MTLRenderPassDescriptor *renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    MTLRenderPassColorAttachmentDescriptor *colorAttachmentDescriptor = renderPassDescriptor.colorAttachments[0];
    colorAttachmentDescriptor.texture = [drawable texture];
    colorAttachmentDescriptor.loadAction = MTLLoadActionClear;
    colorAttachmentDescriptor.clearColor = MTLClearColorMake(41.0f / 255.0f, 42.0f / 255.0f, 48.0f / 255.0f, 1.0);
    colorAttachmentDescriptor.storeAction = MTLStoreActionStore;

    id <MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [self encodeRenderCommand:renderCommandEncoder];
    [renderCommandEncoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    [renderPassDescriptor release];
}

- (void)encodeRenderCommand:(id <MTLRenderCommandEncoder>)renderCommandEncoder {
    [renderCommandEncoder setRenderPipelineState:renderPipeline];
    [renderCommandEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
    [renderCommandEncoder setFragmentTexture:[grassTexture getTexture] atIndex:0];
    [renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

- (NSSize)frameBufferSizeCallback:(NSSize)size {
    NSLog(@"layer drawable size: %f, %f", layer.drawableSize.width, layer.drawableSize.height);
    layer.drawableSize = size;
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
