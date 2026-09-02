# ADR-018: Capability Execution Security Model

## Status

Accepted

## Context

The current capability execution system allows arbitrary Ruby code to run with full system privileges when capability providers are executed. This creates several critical security vulnerabilities:

1. **Arbitrary Code Execution**: Any registered capability can execute unrestricted Ruby code, including system calls, file operations, and network requests
2. **No Permission Model**: There is no mechanism to declare or enforce what operations a capability is allowed to perform
3. **Unsigned Capabilities**: Third-party capabilities can be registered without verification or trust establishment
4. **Trust Boundary Confusion**: All capabilities, whether built-in or third-party, have equal privileges

Security review findings (Morgan Taylor - Security Specialist):
- **Critical Risk**: Unrestricted capability execution allows arbitrary code execution with system privileges
- **High Risk**: Unsanitized LLM prompts vulnerable to prompt injection attacks
- **High Risk**: No authentication/authorization enables unauthorized agent operations

This is inconsistent with the framework's goal of being production-ready and enabling safe third-party extensions. We need a security model that:
- Provides defense-in-depth protection
- Balances security with Ruby ecosystem norms (gems already execute arbitrary code)
- Enables safe third-party capability development
- Maintains extensibility and ease of use

## Decision

We will implement a **Permission-Based Capability Security Model** with the following components:

### 1. Capability Permission System

Define explicit permissions that capabilities must declare:

```ruby
# Permission types
module Agentic
  module Permissions
    FILE_READ = :file_read
    FILE_WRITE = :file_write
    NETWORK_ACCESS = :network_access
    PROCESS_SPAWN = :process_spawn
    SYSTEM_COMMANDS = :system_commands
    ENV_ACCESS = :env_access
    DATABASE_ACCESS = :database_access
  end
end

# Capability specification with permissions
Agentic::CapabilitySpecification.new(
  name: "web_search",
  description: "Searches the web",
  version: "1.0.0",
  required_permissions: [
    Agentic::Permissions::NETWORK_ACCESS
  ],
  inputs: {...},
  outputs: {...}
)
```

### 2. Capability Allow-List Registry

Implement a curated registry of approved capabilities:

```ruby
module Agentic
  class CapabilityAllowList
    def self.register_trusted(capability_name, signature:, reviewed_by:, approved_at:)
      # Add to allow-list with audit trail
    end

    def self.trusted?(capability_name)
      # Check if capability is approved
    end

    def self.verify_signature(capability, signature)
      # Verify digital signature for third-party capabilities
    end
  end
end
```

### 3. Runtime Permission Enforcement

Check permissions during capability execution:

```ruby
class CapabilityProvider
  def execute(inputs = {})
    # 1. Verify capability is in allow-list (if enforcement enabled)
    verify_allow_list! if Agentic.config.enforce_allow_list

    # 2. Check permissions before execution
    check_permissions!(@capability.required_permissions)

    # 3. Validate inputs
    validate_inputs!(inputs)

    # 4. Execute in monitored context
    result = execute_with_monitoring(inputs)

    # 5. Validate outputs
    validate_outputs!(result)
  end

  private

  def check_permissions!(permissions)
    permissions.each do |permission|
      unless Agentic.config.granted_permissions.include?(permission)
        raise Agentic::PermissionDeniedError,
          "Capability requires #{permission} but permission not granted"
      end
    end
  end
end
```

### 4. Configuration-Based Permission Granting

Allow deployment-level permission configuration:

```ruby
# In application configuration
Agentic.configure do |config|
  # Grant specific permissions
  config.granted_permissions = [
    Agentic::Permissions::NETWORK_ACCESS,
    Agentic::Permissions::FILE_READ
  ]

  # Enforce allow-list (default: true in production)
  config.enforce_allow_list = true

  # Enable capability signatures
  config.require_signatures = true
end
```

### 5. Capability Digital Signatures

For third-party capabilities, require digital signatures:

```ruby
# Register capability with signature
Agentic.register_capability(
  capability_spec,
  capability_provider,
  signature: "SHA256:base64_encoded_signature",
  public_key: developer_public_key
)
```

### 6. Audit Logging

Log all capability executions with security context:

```ruby
# Log format
{
  timestamp: "2025-11-11T10:30:00Z",
  capability: "web_search",
  version: "1.0.0",
  permissions_used: [:network_access],
  user_id: "user_123",
  task_id: "task_456",
  result: "success",
  duration_ms: 1234
}
```

## Consequences

### Positive

1. **Defense-in-Depth Security**: Multiple layers of protection against malicious capabilities
2. **Explicit Trust Model**: Clear distinction between trusted built-in and third-party capabilities
3. **Production-Ready**: Suitable for deployment in security-conscious environments
4. **Audit Trail**: Complete visibility into capability permissions and usage
5. **Gradual Adoption**: Can be disabled in development, enforced in production
6. **Ecosystem Growth**: Safe framework for third-party capability development

### Negative

1. **Increased Complexity**: Additional configuration and management overhead
2. **Developer Friction**: Capability developers must declare permissions and potentially sign code
3. **Performance Impact**: Runtime permission checks add execution overhead (minimal)
4. **Maintenance Burden**: Allow-list must be maintained and reviewed
5. **Partial Protection**: Ruby's dynamic nature means determined attackers can still bypass restrictions

### Neutral

1. **Security vs. Convenience Trade-off**: More secure but less convenient than unrestricted execution
2. **Aligns with Ecosystem Norms**: Similar to how apps request permissions, though gems typically don't
3. **Configuration Required**: Deployments must explicitly grant permissions

## Alternatives Considered

### Alternative 1: Container-Based Sandboxing

**Approach**: Execute capabilities in isolated Docker containers or firejail

**Pros**:
- Strongest isolation
- Prevents system compromise
- Industry-standard approach

**Cons**:
- Very high complexity
- Significant performance overhead
- Poor developer experience
- Incompatible with many Ruby patterns (shared memory, etc.)

**Decision**: Rejected - Too heavy for a Ruby gem's default behavior. Consider as optional enhancement for high-security deployments.

### Alternative 2: No Security Model (Status Quo)

**Approach**: Continue allowing unrestricted execution, rely on developer trust

**Pros**:
- Simplest implementation
- No developer friction
- Aligns with Ruby gem norms

**Cons**:
- Unsuitable for production
- Blocks enterprise adoption
- Creates liability for framework
- Limits ecosystem growth

**Decision**: Rejected - Security risks too high for production framework.

### Alternative 3: Code Review Only

**Approach**: Require manual code review for all third-party capabilities, no runtime enforcement

**Pros**:
- Social + technical control
- Simpler than runtime enforcement
- Flexible

**Cons**:
- Doesn't scale
- No protection against compromised packages
- No runtime visibility
- Relies entirely on review quality

**Decision**: Rejected - Insufficient protection, though code review should still be encouraged.

### Alternative 4: Signed Capabilities Only

**Approach**: Require all capabilities to be digitally signed, reject unsigned

**Pros**:
- Simple model
- Strong trust chain
- Low runtime overhead

**Cons**:
- High barrier to entry for capability developers
- Requires PKI infrastructure
- Doesn't limit what signed capabilities can do

**Decision**: Partially adopted - Signatures required for third-party capabilities, but combined with permission model.

## Implementation Notes

### Phase 1: Permission Framework (High Priority)

1. Define permission enum and constants
2. Add `required_permissions` to `CapabilitySpecification`
3. Implement permission checking in `CapabilityProvider.execute`
4. Add configuration for granted permissions
5. Create `PermissionDeniedError` exception hierarchy

**Estimated Effort**: 3-5 days

### Phase 2: Allow-List Registry (High Priority)

1. Create `CapabilityAllowList` class
2. Populate with built-in trusted capabilities
3. Add enforcement toggle to configuration
4. Implement audit trail for allow-list changes

**Estimated Effort**: 3-5 days

### Phase 3: Digital Signatures (Medium Priority)

1. Add signature verification using Ruby OpenSSL
2. Create developer key registration system
3. Integrate signature checking into capability registration
4. Document signing process for capability developers

**Estimated Effort**: 5-7 days

### Phase 4: Audit Logging (Medium Priority)

1. Integrate with existing observability system
2. Add structured security logs
3. Create security dashboard in CLI
4. Implement log retention and analysis

**Estimated Effort**: 3-5 days

### Phase 5: Sandboxing (Optional - Future)

1. Design container-based execution interface
2. Implement Docker/firejail backend
3. Add configuration for sandbox mode
4. Document performance implications

**Estimated Effort**: 2-3 weeks (deferred to v0.4.0+)

### Testing Strategy

1. **Unit Tests**: Permission checking logic, signature verification
2. **Integration Tests**: End-to-end capability execution with various permission scenarios
3. **Security Tests**: Attempt to bypass permission checks, verify enforcement
4. **Performance Tests**: Measure overhead of permission checking

### Migration Path

1. **v0.3.0**: Introduce permission system, disabled by default (warn only)
2. **v0.3.1**: Enable by default in production environment, opt-out available
3. **v0.4.0**: Required for all capabilities, remove opt-out

### Documentation Requirements

1. **Capability Developer Guide**: How to declare permissions and sign capabilities
2. **Security Best Practices**: Recommendations for production deployments
3. **Permission Reference**: Complete list of permissions and what they allow
4. **Audit Guide**: How to monitor and analyze capability usage

## Related ADRs

- ADR-003: Content Safety (prompt injection prevention)
- ADR-004: Agent Permissions (agent-level authorization)
- ADR-006: Extension System (third-party capability architecture)
- ADR-016: Agent Assembly Engine (integration point for security checks)

## Future Considerations

1. **Fine-Grained Permissions**: More specific permissions (e.g., file_read_temp, network_access_https)
2. **Resource Limits**: CPU, memory, and time limits per capability execution
3. **Capability Isolation**: Separate processes or threads for capability execution
4. **Permission Scopes**: Limit permissions to specific paths, domains, or resources
5. **Runtime Policy Engine**: Dynamic permission decisions based on context
6. **Capability Marketplace**: Verified capability directory with security ratings
7. **Security Certifications**: Third-party security audits for high-trust capabilities
