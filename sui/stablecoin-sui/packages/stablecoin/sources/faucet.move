// Copyright 2024 Circle Internet Group, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module stablecoin::faucet {
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    use stablecoin::treasury::{Self, Treasury};

    // === Errors ===
    const ERateLimitExceeded: u64 = 1;
    const ENotOwner: u64 = 4;
    const EInvalidAmount: u64 = 5;
    const EInvalidTreasury: u64 = 6;

    // === Defaults ===
    // Note: These defaults are USDC-friendly (6 decimals), but the module is generic over T.
    const MAX_REQUEST_AMOUNT: u64 = 1_000_000 /* 1M units */ * 1_000_000 /* 10^6 decimals */;
    const RATE_LIMIT_PERIOD_MS: u64 = 3_600_000; // 1 hour in ms (reduced for testing)
    const MAX_REQUESTS_PER_PERIOD: u64 = 100; // Increased for testing

    // === Objects ===

    public struct Faucet<phantom T> has key, store {
        id: UID,
        owner: address,
        treasury_id: ID,
        user_last_request_ms: Table<address, u64>,
        user_request_count: Table<address, u64>,
        total_distributed: u64,
    }

    // === Events ===

    public struct FaucetRequest<phantom T> has copy, drop {
        user: address,
        amount: u64,
        timestamp_ms: u64,
    }

    // === Views ===

    public fun total_distributed<T>(f: &Faucet<T>): u64 { f.total_distributed }
    public fun owner<T>(f: &Faucet<T>): address { f.owner }
    public fun treasury_id<T>(f: &Faucet<T>): ID { f.treasury_id }

    // === Entry functions ===

    /// Create and share a Faucet bound to the given Treasury<T>.
    /// Note: This is not a module 'init'; call this explicitly after publishing.
    public entry fun create<T>(treasury: &Treasury<T>, ctx: &mut TxContext) {
        let faucet = Faucet<T> {
            id: object::new(ctx),
            owner: ctx.sender(),
            treasury_id: object::id(treasury),
            user_last_request_ms: table::new(ctx),
            user_request_count: table::new(ctx),
            total_distributed: 0,
        };
        transfer::public_share_object(faucet);
    }

    /// Request `amount` for the sender, rate-limited.
    /// Devnet-only: internally calls `treasury::devnet_mint_and_transfer<T>`.
    public entry fun request<T>(
        faucet: &mut Faucet<T>,
        treasury: &mut Treasury<T>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(object::id(treasury) == faucet.treasury_id, EInvalidTreasury);
        let user = ctx.sender();
        mint_with_rate_limit(faucet, treasury, user, amount, clock, ctx);
    }

    /// Request `amount` to be sent to a specific `recipient`, rate-limited per sender.
    /// Devnet-only: internally calls `treasury::devnet_mint_and_transfer<T>`.
    public entry fun request_for<T>(
        faucet: &mut Faucet<T>,
        treasury: &mut Treasury<T>,
        recipient: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(object::id(treasury) == faucet.treasury_id, EInvalidTreasury);
        mint_with_rate_limit(faucet, treasury, recipient, amount, clock, ctx);
    }

    /// Transfer ownership of the faucet object.
    public entry fun transfer_ownership<T>(faucet: &mut Faucet<T>, new_owner: address, ctx: &mut TxContext) {
        assert!(ctx.sender() == faucet.owner, ENotOwner);
        faucet.owner = new_owner;
    }

    // === Internal ===

    fun mint_with_rate_limit<T>(
        faucet: &mut Faucet<T>,
        treasury: &mut Treasury<T>,
        recipient: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(amount > 0 && amount <= MAX_REQUEST_AMOUNT, EInvalidAmount);

        let now = clock::timestamp_ms(clock);

        let last = if (table::contains(&faucet.user_last_request_ms, ctx.sender())) {
            *table::borrow(&faucet.user_last_request_ms, ctx.sender())
        } else { 0 };

        let count = if (table::contains(&faucet.user_request_count, ctx.sender())) {
            *table::borrow(&faucet.user_request_count, ctx.sender())
        } else { 0 };

        let effective_count = if (now - last >= RATE_LIMIT_PERIOD_MS) { 0 } else { count };
        assert!(effective_count < MAX_REQUESTS_PER_PERIOD, ERateLimitExceeded);

        // Devnet-only mint path from the wrapped TreasuryCap
        treasury::devnet_mint_and_transfer<T>(treasury, amount, recipient, ctx);

        let updated_count = effective_count + 1;

        if (table::contains(&faucet.user_last_request_ms, ctx.sender())) {
            *table::borrow_mut(&mut faucet.user_last_request_ms, ctx.sender()) = now;
        } else {
            table::add(&mut faucet.user_last_request_ms, ctx.sender(), now);
        };

        if (table::contains(&faucet.user_request_count, ctx.sender())) {
            *table::borrow_mut(&mut faucet.user_request_count, ctx.sender()) = updated_count;
        } else {
            table::add(&mut faucet.user_request_count, ctx.sender(), updated_count);
        };

        faucet.total_distributed = faucet.total_distributed + amount;
        event::emit(FaucetRequest<T> { user: recipient, amount, timestamp_ms: now });
    }
}
