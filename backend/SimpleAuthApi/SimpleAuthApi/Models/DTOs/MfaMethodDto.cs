namespace SimpleAuthApi.Models.DTOs
{
    public class MfaMethodDto
    {
        public int Id { get; set; }
        public string Type { get; set; } = string.Empty;
        public bool IsEnabled { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
