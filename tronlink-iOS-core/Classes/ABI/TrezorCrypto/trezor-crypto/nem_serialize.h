/* Check the entire block before writing, including each blob's length prefix.
 * Consume remaining capacity field by field so size calculations cannot wrap.
 */
{
	if (ctx->offset > ctx->size) {
		return false;
	}
	size_t remaining = ctx->size - ctx->offset;

#define serialize_u32(data) \
	if (!nem_reserve(&remaining, sizeof(uint32_t))) return false;
#define serialize_u64(data) \
	if (!nem_reserve(&remaining, sizeof(uint64_t))) return false;
#define serialize_write(data, length) \
	{ \
		const size_t field_length = (length); \
		if (field_length > UINT32_MAX || \
			!nem_reserve(&remaining, sizeof(uint32_t)) || \
			!nem_reserve(&remaining, field_length)) return false; \
	}

	NEM_SERIALIZE
}

#undef serialize_u32
#undef serialize_u64
#undef serialize_write

#define serialize_u32(data)           nem_write_u32(ctx, (data));
#define serialize_u64(data)           nem_write_u64(ctx, (data));
#define serialize_write(data, length) nem_write(ctx, (data), (length));

NEM_SERIALIZE

#undef serialize_u32
#undef serialize_u64
#undef serialize_write

#undef NEM_SERIALIZE
