# Simulate an HTTP chunk header arriving before its payload. read(io, n) may
# temporarily return no bytes without reaching EOF; the next packet is still valid.
mutable struct PacketBoundaryIO <: IO
    body::IOBuffer
    header_pending::Bool
end
Base.eof(io::PacketBoundaryIO) = eof(io.body)
Base.bytesavailable(io::PacketBoundaryIO) = io.header_pending ? 0 : min(1, bytesavailable(io.body))
function Base.read(io::PacketBoundaryIO, count::Integer)
    if io.header_pending
        io.header_pending = false
        return UInt8[]
    end
    return read(io.body, min(1, count))
end

@testset "SSE handles empty packet boundaries and split UTF-8" begin
    io = PacketBoundaryIO(IOBuffer("data: hé🙂\r\n\r\n"), true)
    frames = parse_sse(io)
    @test length(frames) == 1
    @test only(frames).data == "hé🙂"
    @test eof(io)
end

# A byte stream that hands out its body a few bytes per read, like a socket.
mutable struct TrickleIO <: IO
    body::IOBuffer
    size::Int
end
Base.eof(io::TrickleIO) = eof(io.body)
Base.bytesavailable(io::TrickleIO) = min(io.size, bytesavailable(io.body))
Base.read(io::TrickleIO, count::Integer) = read(io.body, min(io.size, count))

# INV-056: no default size limit (the former 64 KiB line / 1 MiB event
# defaults refused real streams: OpenAI Responses echoes the whole response;
# Gemini sends a 4K image as one 29.7 MB line).
@testset "SSE: a line over the former limits parses by default (INV-056)" begin
    text = "x"^(3 * 1024 * 1024)
    body = "event: response.completed\ndata: {\"text\": \"$text\"}\n\n"
    frames = parse_sse(TrickleIO(IOBuffer(body), 16 * 1024))
    @test length(frames) == 1
    @test only(frames).event == "response.completed"
    @test only(frames).data == "{\"text\": \"$text\"}"
end

@testset "SSE: caps are opt-in, still refuse, and stop an unterminated line early" begin
    @test_throws TransportError parse_sse(IOBuffer("data: too long\n"); max_line_bytes=4)
    @test_throws TransportError parse_sse(IOBuffer("data: 1\ndata: 2\n"); max_event_bytes=8)
    @test_throws ArgumentError parse_sse(IOBuffer("data: x\n"); max_line_bytes=0)
    # A cap is enforced while the line arrives: 4 MiB of body, no newline,
    # refused long before the end.
    io = TrickleIO(IOBuffer("data: " * "a"^(4 * 1024 * 1024)), 16 * 1024)
    @test_throws TransportError parse_sse(io; max_line_bytes=64 * 1024)
    @test !eof(io)
end

@testset "SSE: chunked reads match one-shot parsing for any chunking" begin
    pieces = ["a", "\n", "bc", "\r\n", "\r", "\n\n", "data: {}\n", "data: x\n\n", "z"^300]
    seed = UInt32(56)
    rand_below(n) = (seed = seed * UInt32(1103515245) + UInt32(12345); Int(seed >> 8) % n)
    for _ in 1:300
        body = join(pieces[rand_below(length(pieces)) + 1] for _ in 1:rand_below(40))
        want = parse_sse(IOBuffer(body))
        got = parse_sse(TrickleIO(IOBuffer(body), 1 + rand_below(7)))
        @test [(f.event, f.data) for f in got] == [(f.event, f.data) for f in want]
    end
end
