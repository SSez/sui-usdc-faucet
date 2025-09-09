module usdc_faucet::faucet {
    use sui::coin;
    use sui::clock::Clock;
    use sui::event;
    use sui::table::{Self, Table};

    use usdc::usdc::USDC;

    const ERateLimitExceeded: u64 = 1;
    const ENotOwner: u64 = 4;
    const EInvalidAmount: u64 = 5;

    const USDC_MULTIPLIER: u64 = 1_000_000;
    const MAX_REQUEST_AMOUNT: u64 = 1_000_000 * USDC_MULTIPLIER;
    const RATE_LIMIT_PERIOD: u64 = 86_400_000;
    const MAX_REQUESTS_PER_PERIOD: u64 = 3;

    public struct Faucet has key {
        id: UID,
        owner: address,
        treasury_cap_id: ID,
        user_requests: Table<address, u64>,
        user_request_count: Table<address, u64>,
        total_distributed: u64,
    }

    public struct FaucetRequest has copy, drop {
        user: address,
        amount: u64,
        timestamp: u64,
    }

    entry fun init_faucet(
        treasury_cap: coin::TreasuryCap<USDC>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let cap_id = object::id(&treasury_cap);
        let faucet = Faucet {
            id: object::new(ctx),
            owner: sender,
            treasury_cap_id: cap_id,
            user_requests: table::new(ctx),
            user_request_count: table::new(ctx),
            total_distributed: 0,
        };
        transfer::public_transfer(treasury_cap, sender);
        transfer::share_object(faucet);
    }

    entry fun request_tokens(
        faucet: &mut Faucet,
        treasury_cap: &mut coin::TreasuryCap<USDC>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(object::id(treasury_cap) == faucet.treasury_cap_id, ENotOwner);
        let user = tx_context::sender(ctx);
        mint_with_rate_limit(faucet, treasury_cap, user, amount, clock, ctx);
    }

    entry fun request_tokens_for(
        faucet: &mut Faucet,
        treasury_cap: &mut coin::TreasuryCap<USDC>,
        recipient: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(object::id(treasury_cap) == faucet.treasury_cap_id, ENotOwner);
        mint_with_rate_limit(faucet, treasury_cap, recipient, amount, clock, ctx);
    }

    fun mint_with_rate_limit(
        faucet: &mut Faucet,
        treasury_cap: &mut coin::TreasuryCap<USDC>,
        user: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let now = clock.timestamp_ms();

        assert!(amount > 0 && amount <= MAX_REQUEST_AMOUNT, EInvalidAmount);

        let last = if (faucet.user_requests.contains(user)) {
            *faucet.user_requests.borrow(user)
        } else {
            0
        };

        let mut count = if (faucet.user_request_count.contains(user)) {
            *faucet.user_request_count.borrow(user)
        } else {
            0
        };

        if (now - last >= RATE_LIMIT_PERIOD) { count = 0; };

        assert!(count < MAX_REQUESTS_PER_PERIOD, ERateLimitExceeded);

        coin::mint_and_transfer(treasury_cap, amount, user, ctx);

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

    entry fun transfer_ownership(faucet: &mut Faucet, new_owner: address, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == faucet.owner, ENotOwner);
        faucet.owner = new_owner;
    }

    public fun total_distributed(f: &Faucet): u64 { f.total_distributed }
    public fun owner(f: &Faucet): address { f.owner }
}