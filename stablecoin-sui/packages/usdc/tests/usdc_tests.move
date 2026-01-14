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

#[test_only]
module usdc::usdc_tests {
    use std::string;
    use std::unit_test;
    use sui::{
        test_scenario, 
        coin::{Self},
        coin_registry::{Currency},
        deny_list::{Self, DenyList},
    };
    use sui::coin_registry;
    use stablecoin::treasury::Treasury;
    use sui_extensions::upgrade_service::UpgradeService;
    use usdc::usdc::{Self, USDC};

    const DEPLOYER: address = @0x0;
    const RANDOM_ADDRESS: address = @0x10;
    const COIN_REGISTRY_ADDRESS: address = @0xc;

    #[test]
    fun init__should_create_correct_number_of_objects() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        usdc::init_for_testing(scenario.ctx());

        let previous_tx_effects = scenario.next_tx(DEPLOYER);
        let created_len = previous_tx_effects.created().length();
        let frozen_len = previous_tx_effects.frozen().length();
        let shared_len = previous_tx_effects.shared().length();
        unit_test::assert_eq!(created_len, 4);
        unit_test::assert_eq!(frozen_len, 0);
        unit_test::assert_eq!(shared_len, 2); // Shared treasury and upgrade service objects

        scenario.end();
    }

    #[test]
    fun init__should_create_correct_coin_metadata() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        usdc::init_for_testing(scenario.ctx());

        scenario.next_tx(DEPLOYER);
        let currency = test_scenario::take_from_address<Currency<USDC>>(
            &scenario,
            COIN_REGISTRY_ADDRESS
        );
        unit_test::assert_eq!(coin_registry::decimals(&currency), 6);
        unit_test::assert_eq!(coin_registry::name(&currency), string::utf8(b"USDC"));
        unit_test::assert_eq!(coin_registry::symbol(&currency), string::utf8(b"USDC"));
        unit_test::assert_eq!(
            coin_registry::description(&currency),
            string::utf8(b"USDC is a US dollar-backed stablecoin issued by Circle. USDC is designed to provide a faster, safer, and more efficient way to send, spend, and exchange money around the world.")
        );
        unit_test::assert_eq!(
            coin_registry::icon_url(&currency),
            string::utf8(b"https://www.circle.com/hubfs/Brand/USDC/USDC_icon_32x32.png")
        );
        test_scenario::return_to_address(COIN_REGISTRY_ADDRESS, currency);

        scenario.end();
    }

    #[test]
    fun init__should_create_regulated_coin_metadata() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        usdc::init_for_testing(scenario.ctx());

        scenario.next_tx(DEPLOYER);
        let currency = test_scenario::take_from_address<Currency<USDC>>(
            &scenario,
            COIN_REGISTRY_ADDRESS
        );
        unit_test::assert_eq!(coin_registry::deny_cap_id(&currency).is_some(), true);
        test_scenario::return_to_address(COIN_REGISTRY_ADDRESS, currency);

        scenario.end();
    }

    #[test]
    fun init__should_create_shared_treasury_and_wrap_treasury_cap() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        usdc::init_for_testing(scenario.ctx());

        scenario.next_tx(DEPLOYER);
        let treasury = scenario.take_shared<Treasury<USDC>>();
        unit_test::assert_eq!(treasury.total_supply(), 0);
        test_scenario::return_shared(treasury);

        scenario.end();
    }

    #[test]
    fun init__should_create_shared_treasury_and_wrap_deny_cap() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        usdc::init_for_testing(scenario.ctx());
        deny_list::create_for_testing(scenario.ctx());

        scenario.next_tx(DEPLOYER);

        // Check that deny cap is working by adding an address to the deny list
        let mut treasury = scenario.take_shared<Treasury<USDC>>();
        let mut deny_list = scenario.take_shared<DenyList>();

        treasury.blocklist(&mut deny_list, RANDOM_ADDRESS, scenario.ctx());
        unit_test::assert_eq!(coin::deny_list_v2_contains_next_epoch<USDC>(&deny_list, RANDOM_ADDRESS), true);

        test_scenario::return_shared(deny_list);
        test_scenario::return_shared(treasury);

        scenario.end();
    }

    #[test]
    fun init__should_create_shared_upgrade_service() {   
        let mut scenario = test_scenario::begin(DEPLOYER);
        usdc::init_for_testing(scenario.ctx());

        scenario.next_tx(DEPLOYER);
        let upgrade_service = scenario.take_shared<UpgradeService<USDC>>();
        unit_test::assert_eq!(upgrade_service.admin(), DEPLOYER);
        test_scenario::return_shared(upgrade_service);

        scenario.end();
    }
}
