//! Starknet Client implementation using `JsonRpcHttp` provider.
use async_trait::async_trait;

use regex::Regex;
use starknet::{
    core::types::*,
    providers::{jsonrpc::HttpTransport, AnyProvider, JsonRpcClient, Provider},
};
use std::collections::HashMap;
use url::Url;

use super::{StarknetClient, StarknetClientError};

const INPUT_TOO_SHORT: &str = "0x496e70757420746f6f2073686f727420666f7220617267756d656e7473";
const INPUT_TOO_LONG: &str = "0x496e70757420746f6f206c6f6e6720666f7220617267756d656e7473";
const ENTRYPOINT_NOT_FOUND: &str = "EntryPointNotFoundInContract";

#[derive(Debug)]
pub struct StarknetClientHttp {
    /// Provider is kept public to allow custom reuse of
    /// the raw provider elsewhere.
    pub provider: AnyProvider,
}

#[async_trait]
impl StarknetClient for StarknetClientHttp {
    ///
    fn new(rpc_url: &str) -> Result<StarknetClientHttp, StarknetClientError> {
        let rpc_url = Url::parse(rpc_url).map_err(|_| {
            StarknetClientError::Other("Can't parse RPC url to create the provider".to_string())
        })?;

        let provider = AnyProvider::JsonRpcHttp(JsonRpcClient::new(HttpTransport::new(rpc_url)));

        Ok(Self { provider })
    }

    /// Transaction receipts don't have `EmittedEvent` but `Event` instead.
    /// This function aims at converting the `Event` into `EmittedEvent` to
    /// be compatible with all the indexing process.
    async fn events_from_tx_receipt(
        &self,
        transaction_hash: FieldElement,
        keys: Option<Vec<Vec<FieldElement>>>,
    ) -> Result<Vec<EmittedEvent>, StarknetClientError> {
        let receipt = self
            .provider
            .get_transaction_receipt(transaction_hash)
            .await
            .map_err(StarknetClientError::Provider)?;

        let mut block_hash = FieldElement::MAX;
        let mut block_number = u64::MAX;

        let events = match receipt {
            // We must assign the block hash and number for every type
            // of transaction because we don't know in advance which
            // type of txs are present in the block.
            MaybePendingTransactionReceipt::Receipt(r) => match r {
                TransactionReceipt::Invoke(inner) => {
                    block_hash = inner.block_hash;
                    block_number = inner.block_number;
                    inner.events
                }
                TransactionReceipt::L1Handler(inner) => {
                    block_hash = inner.block_hash;
                    block_number = inner.block_number;
                    inner.events
                }
                TransactionReceipt::Declare(inner) => {
                    block_hash = inner.block_hash;
                    block_number = inner.block_number;
                    inner.events
                }
                TransactionReceipt::Deploy(inner) => {
                    block_hash = inner.block_hash;
                    block_number = inner.block_number;
                    inner.events
                }
                TransactionReceipt::DeployAccount(inner) => {
                    block_hash = inner.block_hash;
                    block_number = inner.block_number;
                    inner.events
                }
            },
            // For pending, we don't have the block hash or the block number.
            // Default value of MAX is used.
            MaybePendingTransactionReceipt::PendingReceipt(pr) => match pr {
                PendingTransactionReceipt::Invoke(inner) => inner.events,
                PendingTransactionReceipt::L1Handler(inner) => inner.events,
                PendingTransactionReceipt::Declare(inner) => inner.events,
                PendingTransactionReceipt::Deploy(inner) => inner.events,
                PendingTransactionReceipt::DeployAccount(inner) => inner.events,
            },
        };

        let mut emitted_events = vec![];
        for e in events {
            if keys.is_some()
                && !e.keys.is_empty()
                && keys.as_ref().map_or(false, |keys| keys.contains(&e.keys))
            {
                emitted_events.push(EmittedEvent {
                    from_address: e.from_address,
                    keys: e.keys,
                    data: e.data,
                    block_hash,
                    block_number,
                    transaction_hash,
                })
            }
        }

        Ok(emitted_events)
    }

    ///
    async fn block_id_to_u64(&self, id: &BlockId) -> Result<u64, StarknetClientError> {
        match id {
            BlockId::Tag(BlockTag::Latest) => Ok(self
                .provider
                .block_number()
                .await
                .map_err(StarknetClientError::Provider)?),
            BlockId::Number(n) => Ok(*n),
            _ => Err(StarknetClientError::Conversion(
                "BlockID can´t be converted to u64".to_string(),
            )),
        }
    }

    ///
    fn parse_block_range(
        &self,
        from: &str,
        to: &str,
    ) -> Result<(BlockId, BlockId), StarknetClientError> {
        let from_block = self.parse_block_id(from)?;
        let to_block = self.parse_block_id(to)?;

        Ok((from_block, to_block))
    }

    ///
    fn parse_block_id(&self, id: &str) -> Result<BlockId, StarknetClientError> {
        let regex_block_number = Regex::new("^[0-9]{1,}$").unwrap();

        if id == "latest" {
            Ok(BlockId::Tag(BlockTag::Latest))
        } else if id == "pending" {
            Ok(BlockId::Tag(BlockTag::Pending))
        } else if regex_block_number.is_match(id) {
            Ok(BlockId::Number(id.parse::<u64>().map_err(|_| {
                StarknetClientError::Conversion("Can't convert block id to u64".to_string())
            })?))
        } else {
            Ok(BlockId::Hash(FieldElement::from_hex_be(id).map_err(
                |_| {
                    StarknetClientError::Conversion(
                        "Can't convert block hash from given hexadecimal string".to_string(),
                    )
                },
            )?))
        }
    }

    ///
    async fn block_time(&self, block: BlockId) -> Result<u64, StarknetClientError> {
        let block = self
            .provider
            .get_block_with_tx_hashes(block)
            .await
            .map_err(StarknetClientError::Provider)?;

        let timestamp = match block {
            MaybePendingBlockWithTxHashes::Block(block) => block.timestamp,
            MaybePendingBlockWithTxHashes::PendingBlock(block) => block.timestamp,
        };

        Ok(timestamp)
    }

    /// Retuns the tx hashes of the asked block + the block timestamp.
    async fn block_txs_hashes(
        &self,
        block: BlockId,
    ) -> Result<(u64, Vec<FieldElement>), StarknetClientError> {
        let block = self
            .provider
            .get_block_with_tx_hashes(block)
            .await
            .map_err(StarknetClientError::Provider)?;

        let timestamp = match block {
            MaybePendingBlockWithTxHashes::Block(block) => (block.timestamp, block.transactions),
            MaybePendingBlockWithTxHashes::PendingBlock(block) => {
                (block.timestamp, block.transactions)
            }
        };

        Ok(timestamp)
    }

    ///
    async fn block_number(&self) -> Result<u64, StarknetClientError> {
        Ok(self
            .provider
            .block_number()
            .await
            .map_err(StarknetClientError::Provider)?)
    }

    ///
    async fn fetch_events(
        &self,
        from_block: BlockId,
        to_block: BlockId,
        keys: Option<Vec<Vec<FieldElement>>>,
    ) -> Result<HashMap<u64, Vec<EmittedEvent>>, StarknetClientError> {
        let mut events: HashMap<u64, Vec<EmittedEvent>> = HashMap::new();

        let filter = EventFilter {
            from_block: Some(from_block),
            to_block: Some(to_block),
            address: None,
            keys,
        };

        let chunk_size = 1000;
        let mut continuation_token: Option<String> = None;

        loop {
            let event_page = self
                .provider
                .get_events(filter.clone(), continuation_token, chunk_size)
                .await
                .map_err(StarknetClientError::Provider)?;

            event_page.events.iter().for_each(|e| {
                events
                    .entry(e.block_number)
                    .and_modify(|v| v.push(e.clone()))
                    .or_insert(vec![e.clone()]);
            });

            continuation_token = event_page.continuation_token;

            if continuation_token.is_none() {
                break;
            }
        }

        Ok(events)
    }

    ///
    async fn call_contract(
        &self,
        contract_address: FieldElement,
        selector: FieldElement,
        calldata: Vec<FieldElement>,
        block: BlockId,
    ) -> Result<Vec<FieldElement>, StarknetClientError> {
        let r = self
            .provider
            .call(
                FunctionCall {
                    contract_address,
                    entry_point_selector: selector,
                    calldata,
                },
                block,
            )
            .await;

        match r {
            Ok(felts) => Ok(felts),
            Err(e) => {
                let s = e.to_string();
                if s.contains(ENTRYPOINT_NOT_FOUND) {
                    Err(StarknetClientError::EntrypointNotFound(s))
                } else if s.contains(INPUT_TOO_SHORT) {
                    Err(StarknetClientError::InputTooShort)
                } else if s.contains(INPUT_TOO_LONG) {
                    Err(StarknetClientError::InputTooLong)
                } else {
                    Err(StarknetClientError::Contract(s))
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use starknet::core::utils::get_selector_from_name;
    use std::sync::Arc;
    use tokio;

    #[tokio::test]
    async fn test_contract_error_entrypoint_not_found() {
        let client = Arc::new(
            StarknetClientHttp::new(
                "https://starknet-goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
            )
            .unwrap(),
        );

        let contract_address = FieldElement::from_hex_be(
            "049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
        )
        .unwrap();

        let entry_point_selector = get_selector_from_name("notValidEntryPoint").unwrap();

        let calldata = vec![FieldElement::from_hex_be(
            "01352dd0ac2a462cb53e4f125169b28f13bd6199091a9815c444dcae83056bbc",
        )
        .unwrap()];

        let r = client
            .call_contract(
                contract_address,
                entry_point_selector,
                calldata,
                BlockId::Tag(BlockTag::Latest),
            )
            .await;

        if let Err(StarknetClientError::Contract(e)) = r {
            assert!(e.to_string().contains("not found in contract"));
        } else {
            panic!("Expecting EntrypointNotFound error, got {:?}", r);
        }
    }
}
