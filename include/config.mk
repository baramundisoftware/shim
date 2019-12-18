#
# config.mk
# Peter Jones, 2019-11-22 15:10
#

CONFIG_ITEMS :=
ifneq ($(origin VENDOR_CERT_FILE), undefined)
	CONFIG_VENDOR_CERT:="\#define VENDOR_CERT_FILE \"$(VENDOR_CERT_FILE)\""
	CONFIG_ITEMS+=VENDOR_CERT
else
	CONFIG_ITEMS+=NO_VENDOR_CERT
endif

ifneq ($(origin VENDOR_DBX_FILE), undefined)
	CONFIG_VENDOR_DBX:="\#define VENDOR_DBX_FILE \"$(VENDOR_DBX_FILE)\""
	CONFIG_ITEMS+=VENDOR_DBX
else
	CONFIG_ITEMS+=NO_VENDOR_DBX
endif

ifneq ($(origin OVERRIDE_SECURITY_POLICY), undefined)
	CONFIG_OVERRIDE_SECURITY_POLICY:="\#define OVERRIDE_SECURITY_POLICY"
	CONFIG_ITEMS+=OVERRIDE_SECURITY_POLICY
else
	CONFIG_ITEMS+=DEFAULT_SECURITY_POLICY
endif

ifneq ($(origin ENABLE_HTTPBOOT), undefined)
	CONFIG_ENABLE_HTTPBOOT:="\#define ENABLE_HTTPBOOT"
	CONFIG_ITEMS+=HTTPBOOT
else
	CONFIG_ITEMS+=NO_HTTPBOOT
endif

ifneq ($(origin REQUIRE_TPM), undefined)
	CONFIG_REQUIRE_TPM:="\#define REQUIRE_TPM"
	CONFIG_ITEMS+=REQUIRE_TPM
else
	CONFIG_ITEMS+=NO_REQUIRE_TPM
endif

ifneq ($(origin ENABLE_SHIM_CERT),undefined)
	CONFIG_ENABLE_SHIM_CERT:="\#define ENABLE_SHIM_CERT"
	CONFIG_ITEMS+=ENABLE_SHIM_CERT
else
	CONFIG_ITEMS+=DISABLE_SHIM_CERT
endif

.EXPORT_ALL_VARIABLES:
