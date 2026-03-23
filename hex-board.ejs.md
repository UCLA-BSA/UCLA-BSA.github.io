```{=html}
<div class="hex-grid">
<% 
  const perrow = templateParams.perrow ? parseInt(templateParams.perrow) : 3;
  const totalItems = items.length;
  const remainder = totalItems % perrow;
  const paddingNeeded = remainder === 0 ? 0 : perrow - remainder;
  
  items.forEach((item, index) => {
    const rowIndex = Math.floor(index / perrow);
    const posInRow = index % perrow;
    if (posInRow === 0) {
      const isOffset = rowIndex % 2 === 1;
%>
  <div class="hex-row <%= isOffset ? 'hex-row-offset' : '' %>">
<% } %>
    <div class="hex-wrap">
      <a href="<%- item.path %>" class="hex-link">
        <div class="hex-border">
          <div class="hex-shape">
            <img src="<%- item.image %>" alt="<%= item.title %>"/>
            <div class="hex-label">
              <div class="hex-name"><%= item.title %></div>
              <div class="hex-role"><%= item.subtitle %></div>
            </div>
          </div>
        </div>
      </a>
    </div>
<%
    if (posInRow === perrow - 1 || index === totalItems - 1) {
      if (index === totalItems - 1 && remainder !== 0) {
        for (let p = 0; p < paddingNeeded; p++) {
%>
    <div class="hex-wrap" style="visibility:hidden; width:200px; flex-shrink:0;">
      <div class="hex-border" style="width:200px; height:231px;">
        <div class="hex-shape" style="width:192px; height:222px;"></div>
      </div>
    </div>
<%
        }
      }
%>
  </div>
<% } }) %>
</div>
```