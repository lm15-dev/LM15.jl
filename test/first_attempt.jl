module FirstAttemptTests
using Test, LM15

# 2026-10-10: a budget alone fills effort (MAP-7 rule 3 read the other way); a
# DataPart answer reads through text (types.md §Response convenience).
@testset "a thinking budget alone fills effort" begin
    @test [Reasoning(; thinking_budget=b).effort for b in (512, 1024, 2047, 2048, 8192, 16384, 24576, 32768, 10^6)] ==
        ["minimal", "minimal", "minimal", "low", "medium", "high", "xhigh", "max", "max"]
    @test Reasoning(; effort="high", thinking_budget=1024).effort == "high"
    @test_throws ArgumentError Reasoning()
    @test_throws ArgumentError Reasoning(; effort="none")
end

@testset "a DataPart answer reads through text" begin
    r = Response(; model="m", message=Message(; role="assistant", parts=(DataPart(; value=Dict("ok"=>true)),)), finish_reason="stop", usage=Usage())
    @test LM15.text(r) == "{\"ok\":true}"
end
end
