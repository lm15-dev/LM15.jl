# MAP-12 rule 4 (amended 2026-09-29): each input_audio format reads as its true
# media type; an unknown format is malformed; a builder with no audio slot
# refuses at send (MAP-10).

function audio_body(format)
    return Dict{String,Any}(
        "model" => "gemini-3.8-flash",
        "messages" => Any[Dict{String,Any}(
            "role" => "user",
            "content" => Any[
                Dict{String,Any}("type" => "text", "text" => "Transcribe."),
                Dict{String,Any}(
                    "type" => "input_audio",
                    "input_audio" => Dict{String,Any}("data" => "T2dnUw==", "format" => format),
                ),
            ],
        )],
    )
end

@testset "input_audio reads its true media type (MAP-12 rule 4)" begin
    for (format, media_type) in (
        "wav" => "audio/wav",
        "mp3" => "audio/mpeg",
        "mpeg" => "audio/mpeg",
        "ogg" => "audio/ogg",
        "opus" => "audio/opus",
        "flac" => "audio/flac",
        "aac" => "audio/aac",
        "aiff" => "audio/aiff",
        "webm" => "audio/webm",
    )
        part = request_from_openai_chat(audio_body(format)).messages[1].parts[2]
        @test part isa AudioPart
        @test part.media_type == media_type
        @test part.data == "T2dnUw=="
    end
    @test_throws ArgumentError request_from_openai_chat(audio_body("midi"))
    @test_throws ArgumentError request_from_openai_chat(audio_body(1))
end

@testset "an ogg clip reaches Gemini inline and the chat wire refuses it" begin
    req = request_from_openai_chat(audio_body("ogg"))
    sent = JSON.parse(String(copy(build_request(GeminiLM(api_key="k"), req).body)))
    @test sent["contents"][1]["parts"][2] ==
        Dict("inlineData" => Dict("mimeType" => "audio/ogg", "data" => "T2dnUw=="))
    @test_throws UnsupportedFeatureError build_request(OpenAIChatLM(api_key="k"), req)
end
