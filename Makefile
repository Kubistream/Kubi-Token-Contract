.PHONY: build size rpc \
	token-hyp-deploy-base token-hyp-deploy-mantle token-hyp-deploy-all \
	token-hyp-enroll-base token-hyp-enroll-mantle token-hyp-enroll-all \
	token-hyp-deploy-profiles token-hyp-enroll-profiles \
	deploy deploy-all-profiles enroll-all-profiles

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

# Defaults can be overridden per-call: TOKEN_PROFILE=MUSDC make token-hyp-deploy-base
TOKEN_PROFILE ?= MUSDC
# Optional helpers to reduce nonce/gas errors during batch runs
CAST := $(shell command -v cast 2>/dev/null)
DEPLOYER_ADDRESS ?= $(OWNER)
AUTO_NONCE ?= 1
AUTO_GAS_LIMIT ?= 1
GAS_LIMIT_FRACTION ?= 90
GAS_LIMIT_FALLBACK ?= 30000000
GAS_LIMIT_FALLBACK_BASE ?=
GAS_LIMIT_FALLBACK_MANTLE ?=
GAS_LIMIT ?=
GAS_LIMIT_BASE ?=
GAS_LIMIT_MANTLE ?=
FORGE_SCRIPT_OPTS ?=
# Expand comma-separated TOKEN_PROFILES into a space-separated list for loops (drops empties, strips CR)
CR := $(shell printf '\r')
comma := ,
empty :=
space := $(empty) $(empty)
PROFILES_RAW := $(subst $(CR),,$(subst ",,$(TOKEN_PROFILES)))
PROFILES := $(strip $(subst $(comma),$(space),$(PROFILES_RAW)))
ifeq ($(PROFILES),)
  $(warning TOKEN_PROFILES is empty after parsing; set TOKEN_PROFILES="MUSDC,..." or pass TOKEN_PROFILE=...)
endif

ifneq ($(AUTO_NONCE),0)
  ifneq ($(CAST),)
    ifneq ($(DEPLOYER_ADDRESS),)
      NONCE_BASE ?= $(shell cast nonce --pending "$(DEPLOYER_ADDRESS)" --rpc-url "$(BASE_SEPOLIA_RPC_URL)" 2>/dev/null)
      NONCE_MANTLE ?= $(shell cast nonce --pending "$(DEPLOYER_ADDRESS)" --rpc-url "$(MANTLE_SEPOLIA_RPC_URL)" 2>/dev/null)
    endif
  endif
endif

ifneq ($(AUTO_GAS_LIMIT),0)
  ifneq ($(CAST),)
    BLOCK_GAS_LIMIT_BASE ?= $(shell cast block latest --rpc-url "$(BASE_SEPOLIA_RPC_URL)" --json 2>/dev/null | python -c "import json,sys; j=json.load(sys.stdin); print(int(j['gasLimit'],16))" 2>/dev/null)
    BLOCK_GAS_LIMIT_MANTLE ?= $(shell cast block latest --rpc-url "$(MANTLE_SEPOLIA_RPC_URL)" --json 2>/dev/null | python -c "import json,sys; j=json.load(sys.stdin); print(int(j['gasLimit'],16))" 2>/dev/null)
    ifneq ($(BLOCK_GAS_LIMIT_BASE),)
      GAS_LIMIT_BASE ?= $(shell python -c "print(int($(BLOCK_GAS_LIMIT_BASE) * $(GAS_LIMIT_FRACTION) // 100))" 2>/dev/null)
    endif
    ifneq ($(BLOCK_GAS_LIMIT_MANTLE),)
      GAS_LIMIT_MANTLE ?= $(shell python -c "print(int($(BLOCK_GAS_LIMIT_MANTLE) * $(GAS_LIMIT_FRACTION) // 100))" 2>/dev/null)
    endif
    ifeq ($(BLOCK_GAS_LIMIT_BASE),)
      GAS_LIMIT_BASE ?= $(if $(GAS_LIMIT_FALLBACK_BASE),$(GAS_LIMIT_FALLBACK_BASE),$(GAS_LIMIT_FALLBACK))
    endif
    ifeq ($(BLOCK_GAS_LIMIT_MANTLE),)
      GAS_LIMIT_MANTLE ?= $(if $(GAS_LIMIT_FALLBACK_MANTLE),$(GAS_LIMIT_FALLBACK_MANTLE),$(GAS_LIMIT_FALLBACK))
    endif
  else
    GAS_LIMIT_BASE ?= $(if $(GAS_LIMIT_FALLBACK_BASE),$(GAS_LIMIT_FALLBACK_BASE),$(GAS_LIMIT_FALLBACK))
    GAS_LIMIT_MANTLE ?= $(if $(GAS_LIMIT_FALLBACK_MANTLE),$(GAS_LIMIT_FALLBACK_MANTLE),$(GAS_LIMIT_FALLBACK))
  endif
endif

FORGE_BASE_OPTS := $(FORGE_SCRIPT_OPTS) \
	$(if $(GAS_LIMIT_BASE),--gas-limit $(GAS_LIMIT_BASE),$(if $(GAS_LIMIT),--gas-limit $(GAS_LIMIT),)) \
	$(if $(NONCE_BASE),--nonce $(NONCE_BASE),)
FORGE_MANTLE_OPTS := $(FORGE_SCRIPT_OPTS) \
	$(if $(GAS_LIMIT_MANTLE),--gas-limit $(GAS_LIMIT_MANTLE),$(if $(GAS_LIMIT),--gas-limit $(GAS_LIMIT),)) \
	$(if $(NONCE_MANTLE),--nonce $(NONCE_MANTLE),)

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
		$(FORGE_BASE_OPTS) \
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
		$(FORGE_MANTLE_OPTS) \
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
		$(FORGE_BASE_OPTS) \
		--broadcast -vvv

token-hyp-enroll-mantle:
	@echo "$(CYAN)[TOKEN] Enrolling remote router (Mantle Sepolia)...$(RESET)"
	@TOKEN_PROFILE=$(TOKEN_PROFILE) \
	forge script script/token/EnrollRouters.s.sol:EnrollRouters \
		--rpc-url "$(MANTLE_SEPOLIA_RPC_URL)" \
		$(FORGE_MANTLE_OPTS) \
		--broadcast -vvv

token-hyp-enroll-all:
	@$(MAKE) token-hyp-enroll-base
	@$(MAKE) token-hyp-enroll-mantle

# Convenience bundle: deploy both chains then enroll routers on each
deploy:
	@$(MAKE) token-hyp-deploy-all
	@$(MAKE) token-hyp-enroll-all

# Batch deploy/enroll for all profiles listed in TOKEN_PROFILES
token-hyp-deploy-profiles:
	@echo "$(CYAN)[TOKEN] Deploying TokenHypERC20 for profiles: $(PROFILES)$(RESET)"
	@for PROFILE in $(PROFILES); do \
		if [ -z "$$PROFILE" ]; then continue; fi; \
		echo "$(YELLOW)[TOKEN] ===== $$PROFILE (Base + Mantle) =====$(RESET)"; \
		$(MAKE) --no-print-directory TOKEN_PROFILE=$$PROFILE token-hyp-deploy-all || exit $$?; \
	done

token-hyp-enroll-profiles:
	@echo "$(CYAN)[TOKEN] Enrolling routers for profiles: $(PROFILES)$(RESET)"
	@for PROFILE in $(PROFILES); do \
		if [ -z "$$PROFILE" ]; then continue; fi; \
		echo "$(YELLOW)[TOKEN] ===== $$PROFILE (Base + Mantle) =====$(RESET)"; \
		$(MAKE) --no-print-directory TOKEN_PROFILE=$$PROFILE token-hyp-enroll-all || exit $$?; \
	done

enroll-all-profiles:
	@$(MAKE) token-hyp-enroll-profiles

deploy-all-profiles:
	@$(MAKE) token-hyp-deploy-profiles
	@$(MAKE) token-hyp-enroll-profiles
