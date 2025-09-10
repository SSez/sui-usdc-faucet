module usdc::devnet_helper {
    use sui::tx_context::TxContext;
    use stablecoin::treasury;
    use usdc::usdc::USDC;

    public entry fun grant_treasury_cap_to_recipient(
        t: &mut treasury::Treasury<USDC>,
        recipient: address,
        _ctx: &mut TxContext
    ) {
        treasury::devnet_transfer_treasury_cap(t, recipient, _ctx);
    }

    /// [Devnet-only] Mint `amount` USDC from the shared Treasury and transfer to `recipient`.
    /// This avoids extracting the TreasuryCap and works even when the cap is wrapped under governance.
    public entry fun devnet_mint_to(
        t: &mut treasury::Treasury<USDC>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        treasury::devnet_mint_and_transfer<USDC>(t, amount, recipient, ctx);
    }
}
