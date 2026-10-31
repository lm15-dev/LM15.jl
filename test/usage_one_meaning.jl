# MAP-19 (one meaning per usage counter) and estimate: the Julia surface
# around the contract's mapping/usage.json vectors.
@testset "usage: parts never exceed their wholes (INV-029)" begin
    @test_throws ArgumentError Usage(input_tokens=3, cache_write_tokens=3275)
    @test_throws ArgumentError Usage(input_tokens=10, cache_read_tokens=6, cache_write_tokens=6)
    @test_throws ArgumentError Usage(output_tokens=48, reasoning_tokens=155)
    @test_throws ArgumentError Usage(input_tokens=1, output_tokens=2, total_tokens=10)
    @test Usage(total_tokens=10).total_tokens == 10
    @test Usage(cache_read_tokens=4, reasoning_tokens=7).input_tokens === nothing
end

@testset "usage: reasoning beside the completion (xAI preset)" begin
    raw = Dict{String,Any}(
        "prompt_tokens"=>254,
        "completion_tokens"=>9,
        "total_tokens"=>374,
        "completion_tokens_details"=>Dict{String,Any}("reasoning_tokens"=>111),
    )
    @test LM15.usage_from("openai-chat", raw; reasoning_usage="separate").output_tokens == 120
    withheld = LM15.usage_from("openai-chat", raw)
    @test withheld.output_tokens === nothing && withheld.total_tokens == 374
end

@testset "estimate: exact or nothing" begin
    sol = InferencePricing(;
        input_per_million=2.0,
        output_per_million=10.0,
        cache_read_per_million=0.1,
        cache_write_per_million=2.5,
        tiers=(
            PricingTier(;
                above_input_tokens=272000,
                input_per_million=4.0,
                output_per_million=15.0,
                cache_read_per_million=0.2,
                cache_write_per_million=5.0,
            ),
        ),
    )
    @test estimate(
        sol,
        Usage(;
            input_tokens=100000, output_tokens=1000, cache_read_tokens=90000, cache_write_tokens=0
        ),
    ) == 0.039
    @test estimate(
        sol,
        Usage(;
            input_tokens=300000, output_tokens=1000, cache_read_tokens=290000, cache_write_tokens=0
        ),
    ) == 0.113
    @test estimate(sol, Usage(; input_tokens=10, output_tokens=1)) === nothing
    @test_throws ArgumentError InferencePricing(;
        tiers=(PricingTier(; above_input_tokens=2), PricingTier(; above_input_tokens=1))
    )
    @test_throws ArgumentError PricingTier(; above_input_tokens=0)
end
