module usdc_faucet::faucet {
    use sui::coin;
    use sui::clock::Clock;
    use sui::event;
    use sui::table::{Self, Table};

    use usdc::usdc::USDC;

    /// Errors
    const ERateLimitExceeded: u64 = 1;
    const ENotOwner: u64 = 4;
    const EInvalidAmount: u64 = 5;

    /// Constants
    const USDC_MULTIPLIER: u64 = 1_000_000;                // 10^6 decimals
    const MAX_REQUEST_AMOUNT: u64 = 1_000_000 * USDC_MULTIPLIER; // 1,000,000 USDC
    const RATE_LIMIT_PERIOD: u64 = 86_400_000;             // 24h in ms
    const MAX_REQUESTS_PER_PERIOD: u64 = 3;

    /// Faucet struct holds the TreasuryCap
    public struct Faucet has key {
        id: UID,
        owner: address,
        treasury_cap: coin::TreasuryCap<USDC>,
        user_requests: Table<address, u64>,
        user_request_count: Table<address, u64>,
        total_distributed: u64,
    }

    public struct FaucetRequest has copy, drop {
        user: address,
        amount: u64,
        timestamp: u64,
    }

    /// Initialize faucet with our TreasuryCap<USDC>
    public fun init_faucet(
        treasury_cap: coin::TreasuryCap<USDC>,
        ctx: &mut TxContext
    ) {
        let faucet = Faucet {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            treasury_cap,
            user_requests: table::new(ctx),
            user_request_count: table::new(ctx),
            total_distributed: 0,
        };
        transfer::share_object(faucet);
    }

    /// Mint user request amount if limits allow
    public fun request_tokens(
        faucet: &mut Faucet,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        let now = clock.timestamp_ms();

        assert!(amount > 0 && amount <= MAX_REQUEST_AMOUNT, EInvalidAmount);

        let last = if (faucet.user_requests.contains(user)) {
            *faucet.user_requests.borrow(user)
        } else { 0 };

        let mut count = if (faucet.user_request_count.contains(user)) {
            *faucet.user_request_count.borrow(user)
        } else { 0 };

        if (now - last >= RATE_LIMIT_PERIOD) { count = 0; };

        assert!(count < MAX_REQUESTS_PER_PERIOD, ERateLimitExceeded);

        // Mint with TreasuryCap directly
        coin::mint_and_transfer(&mut faucet.treasury_cap, amount, user, ctx);

        if (faucet.user_requests.contains(user)) {
            *faucet.user_requests.borrow_mut(user) = now;
        } else {
            faucet.user_requests.add(user, now);
        };

        if (faucet.user_request_count.contains(user)) {
            *faucet.user_request_count.borrow_mut(user) = count + 1;
        } else {
            faucet.user_request_count.add(user, 1);
        };

        faucet.total_distributed = faucet.total_distributed + amount;

        event::emit(FaucetRequest { user, amount, timestamp: now });
    }

    /// Mint to a specified recipient address (server-signer / admin-driven flow)
    /// Applies the same rate limits but keyed by the recipient address.
    public fun request_tokens_for(
        faucet: &mut Faucet,
        recipient: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let user = recipient;
        let now = clock.timestamp_ms();

        assert!(amount > 0 && amount <= MAX_REQUEST_AMOUNT, EInvalidAmount);

        let last = if (faucet.user_requests.contains(user)) {
            *faucet.user_requests.borrow(user)
        } else { 0 };

        let mut count = if (faucet.user_request_count.contains(user)) {
            *faucet.user_request_count.borrow(user)
        } else { 0 };

        if (now - last >= RATE_LIMIT_PERIOD) { count = 0; };

        assert!(count < MAX_REQUESTS_PER_PERIOD, ERateLimitExceeded);

        // Mint with TreasuryCap directly to recipient
        coin::mint_and_transfer(&mut faucet.treasury_cap, amount, user, ctx);

        if (faucet.user_requests.contains(user)) {
            *faucet.user_requests.borrow_mut(user) = now;
        } else {
            faucet.user_requests.add(user, now);
        };

        if (faucet.user_request_count.contains(user)) {
            *faucet.user_request_count.borrow_mut(user) = count + 1;
        } else {
            faucet.user_request_count.add(user, 1);
        };

        faucet.total_distributed = faucet.total_distributed + amount;

        event::emit(FaucetRequest { user, amount, timestamp: now });
    }

    /// Transfer ownership of the faucet
    public fun transfer_ownership(faucet: &mut Faucet, new_owner: address, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == faucet.owner, ENotOwner);
        faucet.owner = new_owner;
    }

    /// Views
    public fun total_distributed(f: &Faucet): u64 { f.total_distributed }
    public fun owner(f: &Faucet): address { f.owner }
}