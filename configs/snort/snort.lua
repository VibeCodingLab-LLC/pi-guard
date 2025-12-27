-- =============================================================================
-- Pi Guard - Snort 3 Configuration
-- Optimized for Raspberry Pi 3A+ (512MB RAM)
--
-- Key optimizations:
--   - Minimal rule set (home network threats only)
--   - Reduced memory buffers
--   - CPU/memory limits via systemd
--   - Disabled irrelevant detectors
-- =============================================================================

-- Home network definition
HOME_NET = '192.168.0.0/16'
EXTERNAL_NET = '!$HOME_NET'

-- Additional network variables
DNS_SERVERS = '$HOME_NET'
SMTP_SERVERS = '$HOME_NET'
HTTP_SERVERS = '$HOME_NET'
SQL_SERVERS = '$HOME_NET'
TELNET_SERVERS = '$HOME_NET'
SSH_SERVERS = '$HOME_NET'

-- Paths
RULE_PATH = '/etc/snort/rules'
BUILTIN_RULE_PATH = '/etc/snort/builtin_rules'
PLUGIN_PATH = '/usr/lib/snort/plugins'
WHITE_LIST_PATH = '/etc/snort/lists'
BLACK_LIST_PATH = '/etc/snort/lists'

-- =============================================================================
-- Detection Engine (Optimized for Pi)
-- =============================================================================
detection = {
    -- Use Hyperscan for better performance (if available)
    search_method = 'hyperscan',
    -- Fallback for systems without Hyperscan
    -- search_method = 'ac_full',
    
    -- Reduce memory usage
    split_any_any = true,
    max_pattern_len = 20,
}

-- =============================================================================
-- Stream Processing (Reduced for Pi)
-- =============================================================================
stream = {
    -- Track fewer sessions
    max_flows = 8192,
}

stream_tcp = {
    -- Reduced buffers for Pi memory constraints
    max_queued_bytes = 1048576,  -- 1MB instead of default 8MB
    max_queued_segs = 2048,
    
    -- Session tracking
    session_timeout = 30,
    
    -- Reassembly (essential for detection)
    reassemble_async = true,
}

stream_udp = {
    session_timeout = 30,
}

-- =============================================================================
-- Decoders
-- =============================================================================
normalizer = {
    tcp = {
        ips = true,
    },
}

-- =============================================================================
-- Logging (Alert Fast - low overhead)
-- =============================================================================
alert_fast = {
    file = true,
    packet = false,  -- Don't log full packets (saves disk)
}

-- Optional: JSON alerts for parsing
-- alert_json = {
--     file = true,
--     fields = 'timestamp msg src_addr src_port dst_addr dst_port',
-- }

-- =============================================================================
-- Suppression & Thresholds
-- =============================================================================
-- Load suppression rules to reduce false positives
-- include '/etc/snort/threshold.conf'

-- =============================================================================
-- IPS Rules (Minimal set for home networks)
-- =============================================================================
ips = {
    -- Enable built-in decoder rules
    enable_builtin_rules = true,
    
    -- Variables
    variables = default_variables,
    
    -- Rules - ONLY essential categories
    -- Disabled: protocol-icmp, policy-*, info-*, etc.
    rules = [[
        # Community rules
        include $RULE_PATH/snort3-community.rules
        
        # Priority: Malware & Exploits (what actually matters)
        # These are the rules you WANT active:
        # - malware-cnc (command & control traffic)
        # - exploit-kit (browser/plugin exploits)
        # - indicator-shellcode (shell code detection)
        # - server-webapp (web application attacks)
        
        # If you have local rules:
        # include $RULE_PATH/local.rules
    ]],
}

-- =============================================================================
-- Performance Tweaks
-- =============================================================================
-- These are hints for systemd service limits
-- Actual limits set in /etc/systemd/system/snort.service:
--   MemoryMax=300M
--   CPUQuota=50%

-- =============================================================================
-- Preprocessors to DISABLE (reduce CPU/memory)
-- =============================================================================
-- Uncomment to disable heavy preprocessors not needed for home use:
-- 
-- reputation = nil  -- IP reputation (needs subscription)
-- file_id = nil     -- File identification (heavy)
-- http2_inspect = nil  -- HTTP/2 (overkill for home)
