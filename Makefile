.PHONY: build size rpc \
	token-hyp-deploy-base token-hyp-deploy-mantle token-hyp-deploy-all \
	token-hyp-enroll-base token-hyp-enroll-mantle token-hyp-enroll-all \
	deploy

GREEN := \033[0;32m
CYAN := \033[0;36m
YELLOW := \033[1;33m
RED := \033[0;31m
RESET := \033[0m

# Single env focused on TokenHypERC20
ENV_FILE := .env.token

ifneq (,$(wildcard $(ENV_FILE)))
  include $(ENV_FILE)
  export $(shell sed 's/=.*//' $(ENV_FILE))
else
  $(error Missing $(ENV_FILE) for target $(MAKECMDGOALS))
endif

# Defaults can be overridden per-call: TOKEN_PROFILE=MIDRX make token-hyp-deploy-base
TOKEN_PROFILE ?= MIDRX

build:
	@clear
	@echo "$(CYAN)[BUILD] Compiling smart contract...$(RESET)"
	@forge build

size:
	@clear
	@echo "$(GREEN)[REPORT] Generate size report...$(RESET)"
	@forge build --sizes

rpc:
	@clear
	@echo "$(GREEN)[REPORT] Base RPC: ${BASE_SEPOLIA_RPC_URL}$(RESET)"
	@echo "$(GREEN)[REPORT] Mantle RPC: ${MANTLE_SEPOLIA_RPC_URL}$(RESET)"

# === TokenHypERC20 deploy (Base + Mantle) ===
token-hyp-deploy-base:
	@echo "$(CYAN)[TOKEN] Deploying TokenHypERC20 (Base Sepolia)...$(RESET)"
	@TOKEN_PROFILE=$(TOKEN_PROFILE) \
	MAILBOX=$(BASE_MAILBOX) \
	forge script script/token/DeployTokenHypERC20.s.sol:DeployTokenHypERC20 \
		--rpc-url "$(BASE_SEPOLIA_RPC_URL)" \
		--broadcast \
		--verify \
		--etherscan-api-key "$(ETHERSCAN_API_KEY)" \
		-vvv

token-hyp-deploy-mantle:
	@echo "$(CYAN)[TOKEN] Deploying TokenHypERC20 (Mantle Sepolia)...$(RESET)"
	@TOKEN_PROFILE=$(TOKEN_PROFILE) \
	MAILBOX=$(MANTLE_MAILBOX) \
	forge script script/token/DeployTokenHypERC20.s.sol:DeployTokenHypERC20 \
		--rpc-url "$(MANTLE_SEPOLIA_RPC_URL)" \
		--broadcast \
		--verify \
		--etherscan-api-key "$(ETHERSCAN_API_KEY)" \
		-vvv

token-hyp-deploy-all:
	@$(MAKE) token-hyp-deploy-base
	@$(MAKE) token-hyp-deploy-mantle

# === TokenHypERC20 router enrollment (Base + Mantle) ===
token-hyp-enroll-base:
	@echo "$(CYAN)[TOKEN] Enrolling remote router (Base Sepolia)...$(RESET)"
	@TOKEN_PROFILE=$(TOKEN_PROFILE) \
	forge script script/token/EnrollRouters.s.sol:EnrollRouters \
		--rpc-url "$(BASE_SEPOLIA_RPC_URL)" \
		--broadcast -vvv

token-hyp-enroll-mantle:
	@echo "$(CYAN)[TOKEN] Enrolling remote router (Mantle Sepolia)...$(RESET)"
	@TOKEN_PROFILE=$(TOKEN_PROFILE) \
	forge script script/token/EnrollRouters.s.sol:EnrollRouters \
		--rpc-url "$(MANTLE_SEPOLIA_RPC_URL)" \
		--broadcast -vvv

token-hyp-enroll-all:
	@$(MAKE) token-hyp-enroll-base
	@$(MAKE) token-hyp-enroll-mantle

# Convenience bundle: deploy both chains then enroll routers on each
deploy:
	@$(MAKE) token-hyp-deploy-all
	@$(MAKE) token-hyp-enroll-all
