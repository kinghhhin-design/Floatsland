import AppKit
import MetalKit

/// Show Desktop can hold an AppKit window's last backing image while moving other
/// windows. Present the shelf and its outline together in an independent drawable.
final class ClosingSnapshotView: NSView {
    private let surface = CAMetalLayer()
    private var texture: MTLTexture?

    private struct Renderer {
        let queue: MTLCommandQueue
        let loader: MTKTextureLoader
        let pipeline: MTLRenderPipelineState

        init?() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let queue = device.makeCommandQueue(),
                  let library = try? device.makeLibrary(source: ClosingSnapshotView.shader, options: nil)
            else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "canvasVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "shelfPixel")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
            self.queue = queue
            self.pipeline = pipeline
            self.loader = MTKTextureLoader(device: device)
        }
    }

    private static let renderer = Renderer()

    override func makeBackingLayer() -> CALayer { surface }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override init(frame: NSRect) {
        super.init(frame: frame)
        surface.device = Self.renderer?.queue.device
        surface.pixelFormat = .bgra8Unorm
        surface.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        surface.isOpaque = false
        surface.presentsWithTransaction = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func prepare(_ image: CGImage) -> Bool {
        texture = try? Self.renderer?.loader.newTexture(cgImage: image, options: [
            .SRGB: false, .origin: MTKTextureLoader.Origin.topLeft.rawValue
        ])
        return texture != nil
    }

    func finish() {
        removeFromSuperview()
        texture = nil
    }

    func present(rect: NSRect, opacity: CGFloat, cornerRadius: CGFloat, squareTop: Bool) -> Bool {
        guard let renderer = Self.renderer, let texture, let window else { return false }
        let scale = window.backingScaleFactor
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        guard size.width > 0, size.height > 0 else { return false }
        if surface.drawableSize != size { surface.drawableSize = size }
        guard let drawable = surface.nextDrawable(), let commands = renderer.queue.makeCommandBuffer() else { return false }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        // The triangle covers every pixel, including the transparent area around the shelf.
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.setRenderPipelineState(renderer.pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        // Metal fragment positions are in backing pixels measured from the top left.
        var silhouette = SIMD4<Float>(Float(rect.minX * scale), Float((bounds.height - rect.maxY) * scale),
                                      Float(rect.width * scale), Float(rect.height * scale))
        var appearance = SIMD4<Float>(Float(cornerRadius * scale), Float(opacity), squareTop ? 1 : 0, 0)
        encoder.setFragmentBytes(&silhouette, length: MemoryLayout.size(ofValue: silhouette), index: 0)
        encoder.setFragmentBytes(&appearance, length: MemoryLayout.size(ofValue: appearance), index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
        return true
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;

    vertex float4 canvasVertex(uint vertexID [[vertex_id]]) {
        const float2 vertices[] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
        return float4(vertices[vertexID], 0, 1);
    }

    fragment float4 shelfPixel(float4 position [[position]], texture2d<float> snapshot [[texture(0)]],
                               constant float4 &rect [[buffer(0)]], constant float4 &appearance [[buffer(1)]]) {
        float2 halfSize = rect.zw * 0.5;
        float2 fromCenter = position.xy - rect.xy - halfSize;
        bool useSquareCorner = appearance.z > 0.5 && fromCenter.y < 0;
        float radius = useSquareCorner ? 0 : min(appearance.x, min(halfSize.x, halfSize.y));
        float2 edge = abs(fromCenter) - (halfSize - radius);
        float distance = length(max(edge, 0.0)) + min(max(edge.x, edge.y), 0.0) - radius;
        float coverage = saturate(0.5 - distance);

        float2 imageSize = float2(snapshot.get_width(), snapshot.get_height());
        float scale = min(rect.z / imageSize.x, rect.w / imageSize.y);
        float2 uv = fromCenter / (imageSize * scale) + 0.5;
        constexpr sampler sampleImage(coord::normalized, address::clamp_to_zero, filter::linear);
        float3 color = snapshot.sample(sampleImage, uv).rgb * appearance.y;
        return float4(color * coverage, coverage);
    }
    """
}
