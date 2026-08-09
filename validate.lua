local validate = {}

function validate.username(value)
  return type(value) == "string" and value:match("^[a-z_][a-z0-9_-]*$") ~= nil
end

function validate.hostname(value)
  if type(value) ~= "string" or value == "" then
    return false
  end

  if #value > 253 or value:find("%.%.") or value:sub(1, 1) == "." or value:sub(-1) == "." then
    return false
  end

  for label in value:gmatch("[^%.]+") do
    if #label < 1 or #label > 63 then
      return false
    end

    if label:sub(1, 1) == "-" or label:sub(-1) == "-" then
      return false
    end

    if label:match("^[A-Za-z0-9-]+$") == nil then
      return false
    end
  end

  return true
end

function validate.port(value)
  if type(value) == "number" then
    return value % 1 == 0 and value >= 1 and value <= 65535
  end

  if type(value) ~= "string" or value:match("^%d+$") == nil then
    return false
  end

  local n = tonumber(value)
  return n ~= nil and n >= 1 and n <= 65535
end

function validate.port_list(value)
  if type(value) ~= "string" then
    return false
  end

  if value == "" then
    return true
  end

  for item in value:gmatch("[^,%s]+") do
    if not validate.port(item) then
      return false
    end
  end

  return true
end

function validate.non_empty(value)
  return type(value) == "string" and value:gsub("%s+", "") ~= ""
end

function validate.duration(value)
  return type(value) == "string" and value:match("^[0-9]+[smhd]$") ~= nil
end

function validate.swap_size(value)
  return type(value) == "string" and value:match("^[1-9][0-9]*[KMGTP]?$") ~= nil
end

function validate.ssh_public_key(value)
  if type(value) ~= "string" then
    return false
  end

  local key_type, key_body = value:match("^(%S+)%s+(%S+)")
  if not key_type or not key_body then
    return false
  end

  local supported = {
    ["ssh-ed25519"] = true,
    ["ssh-rsa"] = true,
    ["sk-ssh-ed25519@openssh.com"] = true,
    ["sk-ecdsa-sha2-nistp256@openssh.com"] = true,
  }

  return supported[key_type] == true
    or key_type:match("^ecdsa%-sha2%-nistp[0-9]+$") ~= nil
end

function validate.integer_range(value, min_value, max_value)
  local n = tonumber(value)
  return n ~= nil and n >= min_value and n <= max_value and n % 1 == 0
end

return validate
